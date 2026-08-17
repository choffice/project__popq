class CustomerRegionProvince {
  const CustomerRegionProvince({
    required this.name,
    required this.shortName,
    required this.districts,
  });

  final String name;
  final String shortName;
  final List<String> districts;
}

class CustomerRegionSelection {
  const CustomerRegionSelection({
    required this.province,
    this.district,
  });

  final CustomerRegionProvince province;
  final String? district;

  String get displayLabel {
    final String? selectedDistrict = district?.trim();
    if (selectedDistrict == null || selectedDistrict.isEmpty) {
      return province.shortName;
    }

    return '${province.shortName} $selectedDistrict';
  }

  String get fullLabel {
    final String? selectedDistrict = district?.trim();
    if (selectedDistrict == null || selectedDistrict.isEmpty) {
      return province.name;
    }

    return '${province.name} $selectedDistrict';
  }

  /// 카카오 장소 검색으로 선택 지역의 대표 좌표를 구할 때 사용하는 검색어입니다.
  ///
  /// 예:
  /// - 서울특별시 + 성동구 -> "서울특별시 성동구청"
  /// - 경기도 + 수원시 -> "경기도 수원시청"
  /// - 부산광역시 전체 -> "부산광역시청"
  String get centerSearchKeyword {
    final String? selectedDistrict = district?.trim();
    if (selectedDistrict == null || selectedDistrict.isEmpty) {
      return '${province.name}청';
    }

    return '${province.name} ${selectedDistrict}청';
  }
}

abstract final class CustomerRegionCatalog {
  static const String allDistrictLabel = '전체';

  static const List<CustomerRegionProvince> provinces = <CustomerRegionProvince>[
    CustomerRegionProvince(
      name: '서울특별시',
      shortName: '서울',
      districts: <String>[
        '종로구',
        '중구',
        '용산구',
        '성동구',
        '광진구',
        '동대문구',
        '중랑구',
        '성북구',
        '강북구',
        '도봉구',
        '노원구',
        '은평구',
        '서대문구',
        '마포구',
        '양천구',
        '강서구',
        '구로구',
        '금천구',
        '영등포구',
        '동작구',
        '관악구',
        '서초구',
        '강남구',
        '송파구',
        '강동구',
      ],
    ),
    CustomerRegionProvince(
      name: '부산광역시',
      shortName: '부산',
      districts: <String>[
        '중구',
        '서구',
        '동구',
        '영도구',
        '부산진구',
        '동래구',
        '남구',
        '북구',
        '해운대구',
        '사하구',
        '금정구',
        '강서구',
        '연제구',
        '수영구',
        '사상구',
        '기장군',
      ],
    ),
    CustomerRegionProvince(
      name: '대구광역시',
      shortName: '대구',
      districts: <String>[
        '중구',
        '동구',
        '서구',
        '남구',
        '북구',
        '수성구',
        '달서구',
        '달성군',
        '군위군',
      ],
    ),
    CustomerRegionProvince(
      name: '인천광역시',
      shortName: '인천',
      districts: <String>[
        '제물포구',
        '영종구',
        '미추홀구',
        '연수구',
        '남동구',
        '부평구',
        '계양구',
        '서해구',
        '검단구',
        '강화군',
        '옹진군',
      ],
    ),
    CustomerRegionProvince(
      name: '광주광역시',
      shortName: '광주',
      districts: <String>[
        '동구',
        '서구',
        '남구',
        '북구',
        '광산구',
      ],
    ),
    CustomerRegionProvince(
      name: '대전광역시',
      shortName: '대전',
      districts: <String>[
        '동구',
        '중구',
        '서구',
        '유성구',
        '대덕구',
      ],
    ),
    CustomerRegionProvince(
      name: '울산광역시',
      shortName: '울산',
      districts: <String>[
        '중구',
        '남구',
        '동구',
        '북구',
        '울주군',
      ],
    ),
    CustomerRegionProvince(
      name: '세종특별자치시',
      shortName: '세종',
      districts: <String>[],
    ),
    CustomerRegionProvince(
      name: '경기도',
      shortName: '경기',
      districts: <String>[
        '수원시',
        '성남시',
        '의정부시',
        '안양시',
        '부천시',
        '광명시',
        '평택시',
        '동두천시',
        '안산시',
        '고양시',
        '과천시',
        '구리시',
        '남양주시',
        '오산시',
        '시흥시',
        '군포시',
        '의왕시',
        '하남시',
        '용인시',
        '파주시',
        '이천시',
        '안성시',
        '김포시',
        '화성시',
        '광주시',
        '양주시',
        '포천시',
        '여주시',
        '연천군',
        '가평군',
        '양평군',
      ],
    ),
    CustomerRegionProvince(
      name: '강원특별자치도',
      shortName: '강원',
      districts: <String>[
        '춘천시',
        '원주시',
        '강릉시',
        '동해시',
        '태백시',
        '속초시',
        '삼척시',
        '홍천군',
        '횡성군',
        '영월군',
        '평창군',
        '정선군',
        '철원군',
        '화천군',
        '양구군',
        '인제군',
        '고성군',
        '양양군',
      ],
    ),
    CustomerRegionProvince(
      name: '충청북도',
      shortName: '충북',
      districts: <String>[
        '청주시',
        '충주시',
        '제천시',
        '보은군',
        '옥천군',
        '영동군',
        '증평군',
        '진천군',
        '괴산군',
        '음성군',
        '단양군',
      ],
    ),
    CustomerRegionProvince(
      name: '충청남도',
      shortName: '충남',
      districts: <String>[
        '천안시',
        '공주시',
        '보령시',
        '아산시',
        '서산시',
        '논산시',
        '계룡시',
        '당진시',
        '금산군',
        '부여군',
        '서천군',
        '청양군',
        '홍성군',
        '예산군',
        '태안군',
      ],
    ),
    CustomerRegionProvince(
      name: '전북특별자치도',
      shortName: '전북',
      districts: <String>[
        '전주시',
        '군산시',
        '익산시',
        '정읍시',
        '남원시',
        '김제시',
        '완주군',
        '진안군',
        '무주군',
        '장수군',
        '임실군',
        '순창군',
        '고창군',
        '부안군',
      ],
    ),
    CustomerRegionProvince(
      name: '전라남도',
      shortName: '전남',
      districts: <String>[
        '목포시',
        '여수시',
        '순천시',
        '나주시',
        '광양시',
        '담양군',
        '곡성군',
        '구례군',
        '고흥군',
        '보성군',
        '화순군',
        '장흥군',
        '강진군',
        '해남군',
        '영암군',
        '무안군',
        '함평군',
        '영광군',
        '장성군',
        '완도군',
        '진도군',
        '신안군',
      ],
    ),
    CustomerRegionProvince(
      name: '경상북도',
      shortName: '경북',
      districts: <String>[
        '포항시',
        '경주시',
        '김천시',
        '안동시',
        '구미시',
        '영주시',
        '영천시',
        '상주시',
        '문경시',
        '경산시',
        '의성군',
        '청송군',
        '영양군',
        '영덕군',
        '청도군',
        '고령군',
        '성주군',
        '칠곡군',
        '예천군',
        '봉화군',
        '울진군',
        '울릉군',
      ],
    ),
    CustomerRegionProvince(
      name: '경상남도',
      shortName: '경남',
      districts: <String>[
        '창원시',
        '진주시',
        '통영시',
        '사천시',
        '김해시',
        '밀양시',
        '거제시',
        '양산시',
        '의령군',
        '함안군',
        '창녕군',
        '고성군',
        '남해군',
        '하동군',
        '산청군',
        '함양군',
        '거창군',
        '합천군',
      ],
    ),
    CustomerRegionProvince(
      name: '제주특별자치도',
      shortName: '제주',
      districts: <String>[
        '제주시',
        '서귀포시',
      ],
    ),
  ];

  static CustomerRegionProvince get defaultProvince =>
      provinceByName('부산광역시') ?? provinces.first;

  static CustomerRegionProvince? provinceByName(String name) {
    final String normalized = name.trim();

    for (final CustomerRegionProvince province in provinces) {
      if (province.name == normalized || province.shortName == normalized) {
        return province;
      }
    }

    return null;
  }

  static bool containsDistrict(
    CustomerRegionProvince province,
    String district,
  ) {
    return province.districts.contains(district.trim());
  }
}
