import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../app_version.dart';
import '../models/project.dart';
import '../providers/app_providers.dart';
import '../providers/theme_mode_provider.dart';
import '../providers/ui_scale_provider.dart';
import '../providers/update_provider.dart';
import 'share_import_flow.dart';
import '../layout/responsive.dart';
import '../theme/app_theme.dart';
import '../widgets/about_instalay.dart';
import '../widgets/linx_account_button.dart';
import '../widgets/instalay_wordmark.dart';
import '../widgets/license_dialog.dart';
import '../widgets/project_list_tile.dart';
import '../widgets/theme_mode_button.dart';
import '../widgets/ui_scale_buttons.dart';
import 'editor_screen.dart';
import 'templates_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _consumeLinxLaunch();
      await _consumeAndroidShare();
      // Throttled feed check (download-page desktop only); status surfaces in About.
      ref.read(updateSnapshotProvider.notifier).maybeBackgroundCheck();
      await _scheduleHomePreviewThumbsWhenReady();
    });
  }

  Future<void> _scheduleHomePreviewThumbsWhenReady() async {
    try {
      await ref.read(projectsProvider.future);
    } catch (_) {
      return;
    }
    if (!mounted) return;
    ref.read(projectsProvider.notifier).schedulePreviewThumbsWhenHomeOpen();
  }

  Future<void> _consumeAndroidShare() async {
    final items = ref.read(pendingAndroidShareProvider);
    if (items == null || items.isEmpty) return;
    ref.read(pendingAndroidShareProvider.notifier).state = null;
    await openAndroidShareImport(context, ref, items);
  }

  Future<void> _consumeLinxLaunch() async {
    final intent = ref.read(pendingLinxLaunchProvider);
    if (intent == null || !intent.hasWork) return;
    ref.read(pendingLinxLaunchProvider.notifier).state = null;

    final project = await ref
        .read(projectsProvider.notifier)
        .create(name: intent.albumId != null ? 'Linx import' : 'Linx photos');
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EditorScreen(
          projectId: project.id,
          initialLinxAlbumId: intent.albumId,
          initialLinxVariantIds: intent.variantIds,
        ),
      ),
    );
    if (!mounted) return;
    await _scheduleHomePreviewThumbsWhenReady();
  }

  @override
  Widget build(BuildContext context) {
    final projects = ref.watch(projectsProvider);
    final thumbRendering = ref.watch(previewThumbRenderingProvider);
    final licenseAsync = ref.watch(licenseProvider);
    final wideBar = isWideLayout(context);
    final emptyHome = projects.maybeWhen(
      data: (list) => list.isEmpty,
      orElse: () => false,
    );

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            SvgPicture.asset(
              'assets/branding/instalay_logo.svg',
              height: 28,
              width: 28,
            ),
            if (wideBar) ...[
              const SizedBox(width: 10),
              const Flexible(child: InstaLayWordmark(fontSize: 25.6)), // 20 × 1.28
              const SizedBox(width: 10),
            ] else
              const SizedBox(width: 10),
            Tooltip(
              message: 'About InstaLay',
              child: InkWell(
                onTap: () => showAboutInstaLay(context),
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  child: Text(
                    'v$kAppVersion',
                    style: TextStyle(
                      fontFamily: 'Segoe UI',
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.muted(context, 0.55),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          if (wideBar) ...[
            const UiScaleButtons(),
            const ThemeModeButton(),
            IconButton(
              tooltip: 'About',
              onPressed: () => showAboutInstaLay(context),
              icon: const Icon(Icons.info_outline),
            ),
            IconButton(
              tooltip: 'License',
              onPressed: () async {
                final license = await ref.read(licenseProvider.future);
                if (!context.mounted) return;
                await showLicenseDialog(context, license);
                ref.invalidate(licenseProvider);
              },
              icon: Icon(
                licenseAsync.value?.isLicensed == true
                    ? Icons.verified_outlined
                    : Icons.key_outlined,
              ),
            ),
            IconButton(
              tooltip: 'Canvas templates',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const TemplatesScreen()),
                );
              },
              icon: const Icon(Icons.bookmark_border),
            ),
            IconButton(
              tooltip: 'Refresh',
              onPressed: () async {
                await ref.read(projectsProvider.notifier).refresh();
                if (!context.mounted) return;
                await _scheduleHomePreviewThumbsWhenReady();
              },
              icon: const Icon(Icons.refresh),
            ),
            const LinxAccountButton(),
          ] else ...[
            const LinxAccountButton(),
            const _HomeOverflowMenu(),
          ],
        ],
      ),
      body: projects.when(
        loading: () =>
            const Center(child: CircularProgressIndicator.adaptive()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Could not load projects.\n$e',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SvgPicture.asset(
                        'assets/branding/instalay_logo.svg',
                        height: 72,
                        width: 72,
                      ),
                      const SizedBox(height: 16),
                      const InstaLayWordmark(fontSize: 35.84), // 28 × 1.28
                      const SizedBox(height: 8),
                      Text(
                        'Batch-frame photos for Instagram without awkward crops. '
                        'Pick a ratio, mat, border, and export — or stitch a tapestry '
                        'carousel the way SCRL does.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppTheme.muted(context, 0.6)),
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: () => _newProject(context, ref),
                        icon: const Icon(Icons.add),
                        label: const Text('New project'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(0, 8, 0, 96),
            itemCount: list.length,
            separatorBuilder: (_, _) =>
                Divider(height: 1, color: AppTheme.chrome(context)),
            itemBuilder: (context, index) {
              final project = list[index];
              return ProjectListTile(
                project: project,
                thumbRendering: thumbRendering.contains(project.id),
                onOpen: () => _open(context, project.id),
                onShare: () => _open(context, project.id, share: true),
                onRename: () => _renameProject(context, ref, project),
                onDelete: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Delete project?'),
                      content: Text(
                        'Remove “${project.name}” from this device?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );
                  if (ok == true) {
                    await ref
                        .read(projectsProvider.notifier)
                        .delete(project.id);
                  }
                },
              );
            },
          );
        },
      ),
      floatingActionButton: emptyHome
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _newProject(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('New project'),
            ),
    );
  }

  Future<void> _newProject(BuildContext context, WidgetRef ref) async {
    final project = await ref.read(projectsProvider.notifier).create();
    if (!context.mounted) return;
    await _open(context, project.id);
  }

  Future<void> _renameProject(
    BuildContext context,
    WidgetRef ref,
    Project project,
  ) async {
    final controller = TextEditingController(text: project.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename project'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Name'),
          autofocus: true,
          onSubmitted: (value) => Navigator.pop(ctx, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty || name == project.name) return;
    await ref.read(projectStoreProvider).save(project.copyWith(name: name));
    await ref.read(projectsProvider.notifier).refresh();
  }

  Future<void> _open(
    BuildContext context,
    String projectId, {
    bool share = false,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            EditorScreen(projectId: projectId, openShareOnLoad: share),
      ),
    );
    if (!mounted) return;
    await _scheduleHomePreviewThumbsWhenReady();
  }
}

class _HomeOverflowMenu extends ConsumerWidget {
  const _HomeOverflowMenu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scale = ref.watch(uiScaleProvider);
    final themeMode = ref.watch(themeModeProvider);
    final licenseAsync = ref.watch(licenseProvider);
    final scaleNotifier = ref.read(uiScaleProvider.notifier);
    final percent = (scale * 100).round();
    final atMin = scale <= UiScaleNotifier.minScale;
    final atMax = scale >= UiScaleNotifier.maxScale;
    final atDefault = scale == UiScaleNotifier.defaultScale;
    final licensed = licenseAsync.value?.isLicensed == true;
    final (themeIcon, themeLabel) = switch (themeMode) {
      ThemeMode.system => (Icons.brightness_auto_outlined, 'System'),
      ThemeMode.light => (Icons.light_mode_outlined, 'Light'),
      ThemeMode.dark => (Icons.dark_mode_outlined, 'Dark'),
    };

    return PopupMenuButton<String>(
      tooltip: 'More',
      icon: const Icon(Icons.more_vert),
      onSelected: (action) async {
        switch (action) {
          case 'zoomOut':
            await scaleNotifier.zoomOut();
          case 'resetZoom':
            await scaleNotifier.reset();
          case 'zoomIn':
            await scaleNotifier.zoomIn();
          case 'theme':
            await ref.read(themeModeProvider.notifier).cycle();
          case 'about':
            if (!context.mounted) return;
            showAboutInstaLay(context);
          case 'license':
            final license = await ref.read(licenseProvider.future);
            if (!context.mounted) return;
            await showLicenseDialog(context, license);
            ref.invalidate(licenseProvider);
          case 'templates':
            if (!context.mounted) return;
            await Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const TemplatesScreen()));
          case 'refresh':
            await ref.read(projectsProvider.notifier).refresh();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'zoomOut',
          enabled: !atMin,
          child: _BarMenuRow(
            icon: Icons.zoom_out,
            label: 'Zoom out ($percent%)',
          ),
        ),
        PopupMenuItem(
          value: 'resetZoom',
          enabled: !atDefault,
          child: _BarMenuRow(
            icon: Icons.restart_alt,
            label: 'Reset zoom ($percent%)',
          ),
        ),
        PopupMenuItem(
          value: 'zoomIn',
          enabled: !atMax,
          child: _BarMenuRow(icon: Icons.zoom_in, label: 'Zoom in ($percent%)'),
        ),
        PopupMenuItem(
          value: 'theme',
          child: _BarMenuRow(icon: themeIcon, label: 'Theme: $themeLabel'),
        ),
        const PopupMenuItem(
          value: 'about',
          child: _BarMenuRow(icon: Icons.info_outline, label: 'About'),
        ),
        PopupMenuItem(
          value: 'license',
          child: _BarMenuRow(
            icon: licensed ? Icons.verified_outlined : Icons.key_outlined,
            label: 'License',
          ),
        ),
        const PopupMenuItem(
          value: 'templates',
          child: _BarMenuRow(
            icon: Icons.bookmark_border,
            label: 'Canvas templates',
          ),
        ),
        const PopupMenuItem(
          value: 'refresh',
          child: _BarMenuRow(icon: Icons.refresh, label: 'Refresh'),
        ),
      ],
    );
  }
}

class _BarMenuRow extends StatelessWidget {
  const _BarMenuRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [Icon(icon, size: 22), const SizedBox(width: 12), Text(label)],
    );
  }
}
