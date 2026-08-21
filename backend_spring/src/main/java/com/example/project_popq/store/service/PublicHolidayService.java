package com.example.project_popq.store.service;

import java.io.StringReader;
import java.net.http.HttpClient;
import java.nio.charset.StandardCharsets;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import javax.xml.XMLConstants;
import javax.xml.parsers.DocumentBuilderFactory;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.client.JdkClientHttpRequestFactory;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;
import org.springframework.web.util.UriUtils;
import org.w3c.dom.Element;
import org.w3c.dom.NodeList;
import org.xml.sax.InputSource;

@Slf4j
@Service
public class PublicHolidayService {

    private static final String HOLIDAY_PATH =
            "/B090041/openapi/service/SpcdeInfoService/getRestDeInfo";
    private static final Duration CACHE_TTL = Duration.ofHours(24);
    private static final Duration FAILURE_RETRY_TTL = Duration.ofHours(1);
    private static final DateTimeFormatter API_DATE =
            DateTimeFormatter.BASIC_ISO_DATE;

    private final String serviceKey;
    private final Clock clock;
    private final YearDataLoader yearDataLoader;
    private final Map<Integer, CachedYear> cache = new ConcurrentHashMap<>();
    private final Object cacheLock = new Object();

    @Autowired
    public PublicHolidayService(
            @Value("${popq.public-holiday.base-url}") String baseUrl,
            @Value("${popq.public-holiday.service-key:}") String serviceKey
    ) {
        this.serviceKey = normalizeServiceKey(serviceKey);
        this.clock = Clock.systemUTC();

        JdkClientHttpRequestFactory requestFactory =
                new JdkClientHttpRequestFactory(
                        HttpClient.newBuilder()
                                .connectTimeout(Duration.ofSeconds(3))
                                .build()
                );
        requestFactory.setReadTimeout(Duration.ofSeconds(5));

        RestClient restClient = RestClient.builder()
                .baseUrl(baseUrl)
                .requestFactory(requestFactory)
                .build();
        this.yearDataLoader = year -> restClient.get()
                .uri(uriBuilder -> uriBuilder
                        .path(HOLIDAY_PATH)
                        .queryParam("ServiceKey", this.serviceKey)
                        .queryParam("solYear", year)
                        .queryParam("pageNo", 1)
                        .queryParam("numOfRows", 100)
                        .build())
                .retrieve()
                .body(String.class);
    }

    PublicHolidayService(
            String serviceKey,
            Clock clock,
            YearDataLoader yearDataLoader
    ) {
        this.serviceKey = normalizeServiceKey(serviceKey);
        this.clock = clock;
        this.yearDataLoader = yearDataLoader;
    }

    public Evaluation evaluate(LocalDate date) {
        if (date == null || serviceKey.isEmpty()) {
            return Evaluation.unavailable(date);
        }

        int year = date.getYear();
        Instant now = clock.instant();
        CachedYear cached = cache.get(year);
        if (cached != null && cached.expiresAt().isAfter(now)) {
            return cached.evaluate(date);
        }

        synchronized (cacheLock) {
            cached = cache.get(year);
            if (cached != null && cached.expiresAt().isAfter(now)) {
                return cached.evaluate(date);
            }

            try {
                String response = yearDataLoader.load(year);
                Map<LocalDate, String> holidays = parseHolidayXml(response);
                CachedYear loaded = new CachedYear(
                        holidays,
                        now.plus(CACHE_TTL)
                );
                cache.put(year, loaded);
                return loaded.evaluate(date);
            } catch (Exception exception) {
                log.warn(
                        "Failed to load Korean public holidays for year={}",
                        year,
                        exception
                );
                if (cached != null) {
                    CachedYear reusable = new CachedYear(
                            cached.holidays(),
                            now.plus(FAILURE_RETRY_TTL)
                    );
                    cache.put(year, reusable);
                    return reusable.evaluate(date);
                }
                return Evaluation.unavailable(date);
            }
        }
    }

    static Map<LocalDate, String> parseHolidayXml(String xml) throws Exception {
        if (xml == null || xml.isBlank()) {
            throw new IllegalArgumentException("Public holiday response is empty");
        }

        DocumentBuilderFactory factory = DocumentBuilderFactory.newInstance();
        factory.setFeature(
                "http://apache.org/xml/features/disallow-doctype-decl",
                true
        );
        factory.setFeature(
                "http://xml.org/sax/features/external-general-entities",
                false
        );
        factory.setFeature(
                "http://xml.org/sax/features/external-parameter-entities",
                false
        );
        factory.setAttribute(XMLConstants.ACCESS_EXTERNAL_DTD, "");
        factory.setAttribute(XMLConstants.ACCESS_EXTERNAL_SCHEMA, "");
        factory.setExpandEntityReferences(false);
        factory.setXIncludeAware(false);

        Element root = factory.newDocumentBuilder()
                .parse(new InputSource(new StringReader(xml)))
                .getDocumentElement();
        String resultCode = firstText(root, "resultCode");
        if (!"00".equals(resultCode)) {
            throw new IllegalStateException(
                    "Public holiday API returned resultCode=" + resultCode
            );
        }

        Map<LocalDate, String> holidays = new HashMap<>();
        NodeList items = root.getElementsByTagName("item");
        for (int index = 0; index < items.getLength(); index++) {
            if (!(items.item(index) instanceof Element item)) {
                continue;
            }
            if (!"Y".equalsIgnoreCase(firstText(item, "isHoliday"))) {
                continue;
            }
            String locdate = firstText(item, "locdate");
            if (locdate.length() != 8) {
                continue;
            }
            LocalDate date = LocalDate.parse(locdate, API_DATE);
            holidays.put(date, firstText(item, "dateName"));
        }
        return Map.copyOf(holidays);
    }

    private static String firstText(Element source, String tagName) {
        NodeList values = source.getElementsByTagName(tagName);
        if (values.getLength() == 0 || values.item(0) == null) {
            return "";
        }
        String value = values.item(0).getTextContent();
        return value == null ? "" : value.trim();
    }

    private static String normalize(String value) {
        return value == null ? "" : value.trim();
    }

    static String normalizeServiceKey(String value) {
        String normalized = normalize(value);
        if (!normalized.contains("%")) {
            return normalized;
        }
        try {
            // The portal's single "general authentication key" can be shown
            // URL-encoded. RestClient encodes query parameter values, so decode
            // that representation once to avoid sending a double-encoded key.
            return UriUtils.decode(normalized, StandardCharsets.UTF_8);
        } catch (IllegalArgumentException exception) {
            return normalized;
        }
    }

    @FunctionalInterface
    interface YearDataLoader {
        String load(int year) throws Exception;
    }

    public record Evaluation(
            boolean available,
            LocalDate evaluationDate,
            boolean publicHoliday,
            String holidayName
    ) {
        private static Evaluation unavailable(LocalDate date) {
            return new Evaluation(false, date, false, null);
        }
    }

    private record CachedYear(
            Map<LocalDate, String> holidays,
            Instant expiresAt
    ) {
        private Evaluation evaluate(LocalDate date) {
            String name = holidays.get(date);
            return new Evaluation(true, date, name != null, name);
        }
    }
}
