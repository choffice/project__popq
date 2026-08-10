param(
    [string]$MobileFlutterRoot = "."
)

$ErrorActionPreference = "Stop"

$root = (Resolve-Path $MobileFlutterRoot).Path
$designSystemLib = Join-Path $root "packages\design_system\lib"
$widgetDir = Join-Path $designSystemLib "src\widgets"
$exportFile = Join-Path $designSystemLib "popq_design_system.dart"
$helperFile = Join-Path $widgetDir "popq_top_snack_bar.dart"

if (-not (Test-Path $exportFile)) {
    throw "mobile_flutter 루트에서 실행해 주세요. 찾을 수 없음: $exportFile"
}

New-Item -ItemType Directory -Force -Path $widgetDir | Out-Null

$helperSource = @'
import 'dart:async';

import 'package:flutter/material.dart';

/// POPQ 공통 상단 알림.
///
/// 기존 [SnackBar] 객체를 그대로 받아 내용, 액션, 지속시간을 유지하면서
/// 화면 하단이 아닌 상단 SafeArea 영역에 표시한다.
class PopqTopSnackBar {
  PopqTopSnackBar._();

  static OverlayEntry? _currentEntry;
  static Timer? _dismissTimer;

  static void show(BuildContext context, SnackBar snackBar) {
    hide();

    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(snackBar);
      return;
    }

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (overlayContext) {
        return Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            minimum: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: _PopqTopSnackBarView(
              snackBar: snackBar,
              onDismiss: hide,
            ),
          ),
        );
      },
    );

    _currentEntry = entry;
    overlay.insert(entry);
    _dismissTimer = Timer(snackBar.duration, hide);
  }

  static void hide() {
    _dismissTimer?.cancel();
    _dismissTimer = null;

    final entry = _currentEntry;
    _currentEntry = null;
    entry?.remove();
  }
}

extension PopqTopSnackBarMessengerExtension on ScaffoldMessengerState {
  void showTopSnackBar(SnackBar snackBar) {
    PopqTopSnackBar.show(context, snackBar);
  }

  void hideCurrentTopSnackBar() {
    PopqTopSnackBar.hide();
  }
}

class _PopqTopSnackBarView extends StatelessWidget {
  const _PopqTopSnackBarView({
    required this.snackBar,
    required this.onDismiss,
  });

  final SnackBar snackBar;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final snackBarTheme = theme.snackBarTheme;

    final backgroundColor =
        snackBar.backgroundColor ??
        snackBarTheme.backgroundColor ??
        colorScheme.inverseSurface;

    final contentTextStyle =
        snackBarTheme.contentTextStyle ??
        theme.textTheme.bodyMedium?.copyWith(
          color: colorScheme.onInverseSurface,
        );

    final action = snackBar.action;

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      tween: Tween<double>(begin: -14, end: 0),
      builder: (context, offsetY, child) {
        return Transform.translate(
          offset: Offset(0, offsetY),
          child: child,
        );
      },
      child: Material(
        color: backgroundColor,
        elevation: snackBar.elevation ?? snackBarTheme.elevation ?? 6,
        shadowColor: Colors.black26,
        shape:
            snackBar.shape ??
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding:
              snackBar.padding ??
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: DefaultTextStyle.merge(
                  style: contentTextStyle,
                  child: snackBar.content,
                ),
              ),
              if (action != null) ...[
                const SizedBox(width: 8),
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor:
                        action.textColor ?? colorScheme.inversePrimary,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 36),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () {
                    onDismiss();
                    action.onPressed();
                  },
                  child: Text(action.label),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
'@

Set-Content -Path $helperFile -Value $helperSource -Encoding UTF8

$exportText = Get-Content -Path $exportFile -Raw
$exportLine = "export 'src/widgets/popq_top_snack_bar.dart';"
if ($exportText -notmatch [regex]::Escape($exportLine)) {
    $exportText = $exportText.TrimEnd() + [Environment]::NewLine + $exportLine + [Environment]::NewLine
    Set-Content -Path $exportFile -Value $exportText -Encoding UTF8
}

$appRoots = @(
    (Join-Path $root "apps\customer_app\lib"),
    (Join-Path $root "apps\seller_app\lib")
)

$changedFiles = 0
$showCount = 0
$hideCount = 0

foreach ($appRoot in $appRoots) {
    if (-not (Test-Path $appRoot)) {
        continue
    }

    Get-ChildItem -Path $appRoot -Recurse -Filter *.dart | ForEach-Object {
        $path = $_.FullName
        $text = Get-Content -Path $path -Raw

        if ($text -match '\b(showSnackBar|hideCurrentSnackBar)\s*\(') {
            $original = $text
            $localShowCount = ([regex]::Matches($text, '\bshowSnackBar\s*\(')).Count
            $localHideCount = ([regex]::Matches($text, '\bhideCurrentSnackBar\s*\(')).Count

            $text = [regex]::Replace($text, '\bshowSnackBar\s*\(', 'showTopSnackBar(')
            $text = [regex]::Replace($text, '\bhideCurrentSnackBar\s*\(', 'hideCurrentTopSnackBar(')

            $designImport = "import 'package:popq_design_system/popq_design_system.dart';"
            if ($text -notmatch [regex]::Escape($designImport)) {
                $materialImport = "import 'package:flutter/material.dart';"
                if ($text -match [regex]::Escape($materialImport)) {
                    $text = $text.Replace(
                        $materialImport,
                        $materialImport + [Environment]::NewLine + $designImport
                    )
                }
                else {
                    throw "material.dart import를 찾지 못했습니다: $path"
                }
            }

            if ($text -ne $original) {
                Set-Content -Path $path -Value $text -Encoding UTF8
                $changedFiles++
                $showCount += $localShowCount
                $hideCount += $localHideCount
            }
        }
    }
}

Write-Host ""
Write-Host "POPQ 상단 알림 패치 완료" -ForegroundColor Green
Write-Host "- 수정된 Dart 파일: $changedFiles"
Write-Host "- showSnackBar -> showTopSnackBar: $showCount"
Write-Host "- hideCurrentSnackBar -> hideCurrentTopSnackBar: $hideCount"
Write-Host "- 공통 파일: $helperFile"
Write-Host ""
Write-Host "다음 실행 권장:" -ForegroundColor Cyan
Write-Host "  flutter analyze"
