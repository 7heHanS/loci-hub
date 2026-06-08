import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/utils/db_export_util.dart';
import '../../../core/utils/permission_handler.dart';
import '../../../providers/settings_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isExporting = false;

  Future<void> _exportDatabase() async {
    setState(() => _isExporting = true);
    try {
      final dbExport = getIt<DbExportUtil>();
      final file = await dbExport.exportDbFile();
      
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/x-sqlite3')],
        subject: 'LociHub SQLite DB 백업',
        text: 'LociHub 로컬 SQLite 데이터베이스 백업 파일입니다.',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('DB 내보내기 실패: $e')),
        );
      }
    } finally {
      setState(() => _isExporting = false);
    }
  }

  Future<void> _exportLogsJson() async {
    setState(() => _isExporting = true);
    try {
      final dbExport = getIt<DbExportUtil>();
      final file = await dbExport.exportLocationLogsJson();
      
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/json')],
        subject: 'LociHub LocationLogs 백업 (JSON)',
        text: 'LociHub 위치 로그 JSON 내보내기 파일입니다.',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('JSON 내보내기 실패: $e')),
        );
      }
    } finally {
      setState(() => _isExporting = false);
    }
  }

  Future<void> _exportPhotosJson() async {
    setState(() => _isExporting = true);
    try {
      final dbExport = getIt<DbExportUtil>();
      final file = await dbExport.exportPhotoMetadataJson();
      
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/json')],
        subject: 'LociHub PhotoMetadata 백업 (JSON)',
        text: 'LociHub 사진 메타데이터 JSON 내보내기 파일입니다.',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('JSON 내보내기 실패: $e')),
        );
      }
    } finally {
      setState(() => _isExporting = false);
    }
  }

  String _getPermissionText(PhotoAccessLevel level) {
    switch (level) {
      case PhotoAccessLevel.full:
        return '전체 접근 허용';
      case PhotoAccessLevel.partial:
        return '부분 접근 허용 (선택된 사진만)';
      case PhotoAccessLevel.denied:
        return '거부됨 (사진 매칭 기능 제한)';
    }
  }

  Color _getPermissionColor(PhotoAccessLevel level, ThemeData theme) {
    switch (level) {
      case PhotoAccessLevel.full:
        return Colors.green;
      case PhotoAccessLevel.partial:
        return Colors.orange;
      case PhotoAccessLevel.denied:
        return theme.colorScheme.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tolerance = ref.watch(matchingToleranceProvider);
    final photoPermissionAsync = ref.watch(photoPermissionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('설정'),
      ),
      body: _isExporting
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text('데이터 내보내는 중...', style: theme.textTheme.bodyLarge),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Section 1: UI Configurations
                Text(
                  '동기화 및 매칭 설정',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Column(
                      children: [
                        // Tolerance Dropdown
                        ListTile(
                          leading: const Icon(Icons.timer_outlined),
                          title: const Text('매칭 허용 시간차 오차'),
                          subtitle: const Text('사진과 가장 가까운 위치 로그 간의 최대 오차'),
                          trailing: DropdownButton<int>(
                            value: tolerance,
                            underline: const SizedBox(),
                            icon: const Icon(Icons.arrow_drop_down),
                            items: const [
                              DropdownMenuItem(value: 1, child: Text('1분')),
                              DropdownMenuItem(value: 3, child: Text('3분')),
                              DropdownMenuItem(value: 5, child: Text('5분')),
                              DropdownMenuItem(value: 10, child: Text('10분')),
                              DropdownMenuItem(value: 30, child: Text('30분')),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                ref.read(matchingToleranceProvider.notifier).state = val;
                              }
                            },
                          ),
                        ),
                        const Divider(),
                        
                        // Photo permission state indicator
                        photoPermissionAsync.when(
                          data: (level) => ListTile(
                            leading: const Icon(Icons.photo_library_outlined),
                            title: const Text('사진 라이브러리 접근 권한'),
                            subtitle: Text(
                              _getPermissionText(level),
                              style: TextStyle(
                                color: _getPermissionColor(level, theme),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            trailing: ElevatedButton(
                              onPressed: () async {
                                await AppPermissionHandler.openAppSettingsScreen();
                                // Trigger ref check on return
                                ref.invalidate(photoPermissionProvider);
                              },
                              child: const Text('설정 이동'),
                            ),
                          ),
                          loading: () => const ListTile(
                            leading: Icon(Icons.photo_library_outlined),
                            title: Text('사진 권한 상태 조회 중...'),
                            trailing: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                          error: (err, _) => ListTile(
                            leading: const Icon(Icons.photo_library_outlined),
                            title: const Text('사진 권한 상태 조회 실패'),
                            subtitle: Text('에러: $err'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Section 2: Developer Utilities
                Text(
                  '개발자 데이터 유틸리티',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.storage),
                        title: const Text('SQLite DB 내보내기'),
                        subtitle: const Text('로컬 SQLite .db 파일 추출 및 공유'),
                        trailing: const Icon(Icons.share),
                        onTap: _exportDatabase,
                      ),
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.location_on),
                        title: const Text('위치 로그 내보내기 (JSON)'),
                        subtitle: const Text('수집된 GPS 원시 데이터 공유'),
                        trailing: const Icon(Icons.share),
                        onTap: _exportLogsJson,
                      ),
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.photo_library),
                        title: const Text('사진 메타데이터 내보내기 (JSON)'),
                        subtitle: const Text('매칭된 사진 및 EXIF 기록 공유'),
                        trailing: const Icon(Icons.share),
                        onTap: _exportPhotosJson,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: Text(
                    'LociHub v1.0.0 (Developer Build)',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
    );
  }
}
