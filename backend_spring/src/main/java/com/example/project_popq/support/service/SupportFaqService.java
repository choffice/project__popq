package com.example.project_popq.support.service;

import com.example.project_popq.support.dto.SupportFaqResponse;
import com.example.project_popq.support.repository.SupportFaqRepository;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class SupportFaqService {

  private final SupportFaqRepository supportFaqRepository;

  public List<SupportFaqResponse> getPopularFaqs() {
    return supportFaqRepository
        .findAllByActiveTrueAndPopularTrueOrderByDisplayOrderAscIdAsc()
        .stream()
        .map(SupportFaqResponse::from)
        .toList();
  }

  public List<SupportFaqResponse> getAllFaqs() {
    return supportFaqRepository
        .findAllByActiveTrueOrderByDisplayOrderAscIdAsc()
        .stream()
        .map(SupportFaqResponse::from)
        .toList();
  }

  public List<SupportFaqResponse> searchFaqs(
      String keyword
  ) {
    String normalizedKeyword = normalizeKeyword(keyword);

    if (normalizedKeyword == null) {
      return getPopularFaqs();
    }

    return supportFaqRepository
        .searchActiveFaqs(normalizedKeyword)
        .stream()
        .map(SupportFaqResponse::from)
        .toList();
  }

  private String normalizeKeyword(String keyword) {
    if (keyword == null) {
      return null;
    }

    String normalized = keyword.trim();

    if (normalized.isEmpty()) {
      return null;
    }

    return normalized;
  }
}