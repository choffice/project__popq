import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class BusinessRegistrationOcrResult {
  const BusinessRegistrationOcrResult({
    required this.rawText,
    required this.businessNumber,
    this.businessName,
    this.representativeName,
    this.businessAddress,
  });

  final String rawText;

  /// 화면 확인용 사업자등록번호.
  /// 예: 123-45-67890
  final String businessNumber;

  /// 사업자등록증의 상호 또는 법인명.
  final String? businessName;

  /// 사업자등록증의 대표자명.
  /// 이번 단계에서는 DB에 저장하지 않는다.
  final String? representativeName;

  /// 사업자등록증의 사업장 소재지.
  final String? businessAddress;

  String get businessNumberDigits {
    return businessNumber.replaceAll(
      RegExp(r'[^0-9]'),
      '',
    );
  }
}

class BusinessRegistrationOcrException
    implements Exception {
  const BusinessRegistrationOcrException(
      this.message,
      );

  final String message;

  @override
  String toString() => message;
}

class BusinessRegistrationOcrService {
  Future<BusinessRegistrationOcrResult> recognize({
    required String imagePath,
  }) async {
    final InputImage inputImage =
    InputImage.fromFilePath(imagePath);

    final TextRecognizer recognizer =
    TextRecognizer(
      script: TextRecognitionScript.korean,
    );

    try {
      final RecognizedText recognizedText =
      await recognizer.processImage(
        inputImage,
      );

      final String rawText =
      recognizedText.text.trim();

      if (rawText.isEmpty) {
        throw const BusinessRegistrationOcrException(
          '사진에서 글자를 인식하지 못했습니다. '
              '등록증 전체가 밝고 선명하게 나오도록 다시 촬영해 주세요.',
        );
      }

      final String? businessNumber =
      _extractBusinessNumber(rawText);

      if (businessNumber == null) {
        throw const BusinessRegistrationOcrException(
          '사업자등록번호를 정확히 인식하지 못했습니다. '
              '숫자 10자리가 선명하게 나오도록 다시 촬영해 주세요.',
        );
      }

      final String digits =
      businessNumber.replaceAll(
        RegExp(r'[^0-9]'),
        '',
      );

      if (digits.length != 10) {
        throw BusinessRegistrationOcrException(
          '사업자등록번호는 숫자 10자리여야 합니다. '
              '현재 ${digits.length}자리로 인식되었습니다.',
        );
      }

      final List<String> lines =
      _prepareLines(rawText);

      final String? businessName =
      _extractBusinessName(lines);

      final String? representativeName =
      _extractRepresentativeName(lines);

      final String? businessAddress =
      _extractBusinessAddress(lines);

      return BusinessRegistrationOcrResult(
        rawText: rawText,
        businessNumber: _formatBusinessNumber(
          digits,
        ),
        businessName: businessName,
        representativeName:
        representativeName,
        businessAddress: businessAddress,
      );
    } finally {
      await recognizer.close();
    }
  }

  List<String> _prepareLines(
      String rawText,
      ) {
    return rawText
        .split(RegExp(r'\r?\n'))
        .map(_cleanValue)
        .where(
          (String line) => line.isNotEmpty,
    )
        .toList(
      growable: false,
    );
  }

  String? _extractBusinessName(
      List<String> lines,
      ) {
    return _extractLabeledValue(
      lines: lines,
      labelPatterns: <RegExp>[
        RegExp(
          r'^\s*상\s*호\s*'
          r'(?:\(\s*법\s*인\s*명\s*\))?'
          r'\s*[:：\-]?\s*(.*)$',
        ),
        RegExp(
          r'^\s*법\s*인\s*명'
          r'\s*[:：\-]?\s*(.*)$',
        ),
      ],
      maxFollowingLines: 1,
    );
  }

  String? _extractRepresentativeName(
      List<String> lines,
      ) {
    return _extractLabeledValue(
      lines: lines,
      labelPatterns: <RegExp>[
        RegExp(
          r'^\s*성\s*명\s*'
          r'\(\s*대\s*표\s*자\s*\)'
          r'\s*[:：\-]?\s*(.*)$',
        ),
        RegExp(
          r'^\s*대\s*표\s*자'
          r'(?:\s*성\s*명)?'
          r'\s*[:：\-]?\s*(.*)$',
        ),
        RegExp(
          r'^\s*성\s*명'
          r'\s*[:：\-]?\s*(.*)$',
        ),
      ],
      maxFollowingLines: 1,
    );
  }

  String? _extractBusinessAddress(
      List<String> lines,
      ) {
    return _extractLabeledValue(
      lines: lines,
      labelPatterns: <RegExp>[
        RegExp(
          r'^\s*사\s*업\s*장\s*'
          r'소\s*재\s*지'
          r'\s*[:：\-]?\s*(.*)$',
        ),
        RegExp(
          r'^\s*사\s*업\s*장\s*'
          r'주\s*소'
          r'\s*[:：\-]?\s*(.*)$',
        ),
      ],
      maxFollowingLines: 3,
    );
  }

  String? _extractLabeledValue({
    required List<String> lines,
    required List<RegExp> labelPatterns,
    required int maxFollowingLines,
  }) {
    for (int index = 0;
    index < lines.length;
    index++) {
      final String line = lines[index];

      for (final RegExp pattern
      in labelPatterns) {
        final RegExpMatch? match =
        pattern.firstMatch(line);

        if (match == null) {
          continue;
        }

        final String inlineValue =
        _cleanValue(
          match.group(1) ?? '',
        );

        if (inlineValue.isNotEmpty) {
          return inlineValue;
        }

        final List<String> followingValues =
        <String>[];

        for (int offset = 1;
        offset <= maxFollowingLines;
        offset++) {
          final int nextIndex =
              index + offset;

          if (nextIndex >= lines.length) {
            break;
          }

          final String nextLine =
          lines[nextIndex];

          if (_looksLikeLabel(nextLine)) {
            break;
          }

          final String cleaned =
          _cleanValue(nextLine);

          if (cleaned.isNotEmpty) {
            followingValues.add(cleaned);
          }
        }

        if (followingValues.isNotEmpty) {
          return followingValues.join(' ');
        }
      }
    }

    return null;
  }

  bool _looksLikeLabel(
      String value,
      ) {
    final String compact = value
        .replaceAll(
      RegExp(r'\s+'),
      '',
    )
        .replaceAll('：', ':');

    const List<String> knownLabels =
    <String>[
      '사업자등록번호',
      '사업자번호',
      '등록번호',
      '상호(법인명)',
      '상호',
      '법인명',
      '성명(대표자)',
      '대표자성명',
      '대표자',
      '성명',
      '개업연월일',
      '사업장소재지',
      '사업장주소',
      '본점소재지',
      '사업의종류',
      '업태',
      '종목',
      '교부사유',
      '공동사업자',
      '과세유형',
      '사업자단위과세',
      '전자세금계산서',
    ];

    return knownLabels.any(
      compact.startsWith,
    );
  }

  String _cleanValue(
      String value,
      ) {
    return value
        .replaceAll(
      RegExp(r'\s+'),
      ' ',
    )
        .replaceFirst(
      RegExp(r'^[\s:：\-·ㆍ]+'),
      '',
    )
        .trim();
  }

  String? _extractBusinessNumber(
      String rawText,
      ) {
    final List<String> lines =
    _prepareLines(rawText);

    /*
     * 사업자등록번호 라벨 주변을 우선 검사한다.
     */
    for (int index = 0;
    index < lines.length;
    index++) {
      final String compactLabel =
      lines[index].replaceAll(
        RegExp(r'\s+'),
        '',
      );

      final bool numberLabel =
          compactLabel.contains(
            '사업자등록번호',
          ) ||
              compactLabel.contains(
                '사업자번호',
              ) ||
              compactLabel.contains(
                '등록번호',
              );

      if (!numberLabel) {
        continue;
      }

      final int endIndex =
      index + 3 < lines.length
          ? index + 3
          : lines.length;

      final String nearbyText = lines
          .sublist(
        index,
        endIndex,
      )
          .join(' ');

      final String? nearbyNumber =
      _findNumberPattern(
        nearbyText,
      );

      if (nearbyNumber != null) {
        return nearbyNumber;
      }
    }

    /*
     * 라벨 인식에 실패했을 경우 전체 OCR 원문에서
     * 3-2-5 형태의 숫자 패턴을 다시 찾는다.
     */
    return _findNumberPattern(rawText);
  }

  String? _findNumberPattern(
      String text,
      ) {
    final String normalized = text
        .replaceAll('–', '-')
        .replaceAll('—', '-')
        .replaceAll('－', '-');

    final RegExp pattern = RegExp(
      r'(\d{3})[^\d]{0,4}'
      r'(\d{2})[^\d]{0,4}'
      r'(\d{5})',
    );

    final RegExpMatch? match =
    pattern.firstMatch(normalized);

    if (match == null) {
      return null;
    }

    final String first =
        match.group(1) ?? '';

    final String second =
        match.group(2) ?? '';

    final String third =
        match.group(3) ?? '';

    final String digits =
        '$first$second$third';

    if (digits.length != 10) {
      return null;
    }

    return digits;
  }

  String _formatBusinessNumber(
      String digits,
      ) {
    return '${digits.substring(0, 3)}-'
        '${digits.substring(3, 5)}-'
        '${digits.substring(5, 10)}';
  }
}