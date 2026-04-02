import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/theme.dart';
import '../../shared/widgets/app_backdrop.dart';
import '../../shared/widgets/app_brand_mark.dart';
import '../create/create_controller.dart';
import '../create/create_mode_sheet.dart';
import '../create/create_page.dart';
import '../history/history_page.dart';
import '../settings/settings_page.dart';
import 'main_shell_controller.dart';

class MainShellPage extends GetView<MainShellController> {
  MainShellPage({super.key});

  final List<Widget> _pages = <Widget>[
    const CreatePage.embedded(),
    const HistoryPage.embedded(),
    const SettingsPage.embedded(),
  ];

  final List<_ShellTabMeta> _tabs = const <_ShellTabMeta>[
    _ShellTabMeta(
      title: 'AI创作',
      icon: Icons.auto_awesome_rounded,
      tint: AppTheme.coral,
      supportTint: AppTheme.amber,
    ),
    _ShellTabMeta(
      title: '历史记录',
      icon: Icons.history_toggle_off_rounded,
      tint: AppTheme.sky,
      supportTint: AppTheme.jade,
    ),
    _ShellTabMeta(
      title: '个人中心',
      icon: Icons.account_circle_outlined,
      tint: AppTheme.primary,
      supportTint: AppTheme.amber,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final CreateController createController = Get.find<CreateController>();

    return Obx(() {
      final int index = controller.currentIndex.value;
      final _ShellTabMeta tab = _tabs[index];
      final bool isCreateTab = index == 0;
      final CreateWorkbenchMode createMode = createController.mode;

      return Scaffold(
        backgroundColor: Colors.transparent,
        body: AppBackdrop(
          primaryTint: tab.tint,
          secondaryTint: tab.supportTint,
          tertiaryTint: AppTheme.jade,
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
                  child: Row(
                    children: <Widget>[
                      if (isCreateTab)
                        _HeaderModeButton(
                          label: createController.labelForMode(createMode),
                          onTap: () {
                            showCreateModeSheet(
                              context: context,
                              controller: createController,
                            );
                          },
                        )
                      else
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          width: 7,
                          height: 30,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: <Color>[tab.tint, tab.supportTint],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          tab.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontSize: 28,
                          ),
                        ),
                      ),
                      if (isCreateTab) const SizedBox(width: 8),
                      if (isCreateTab)
                        Expanded(
                          child: Text(
                            createController.labelForMode(createMode),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: AppTheme.muted,
                            ),
                          ),
                        ),
                      const AppBrandMark(size: 34, radius: 10),
                    ],
                  ),
                ),
                Expanded(
                  child: IndexedStack(
                    index: index,
                    children: _pages,
                  ),
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(14, 6, 14, 12),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(22),
            ),
            child: NavigationBar(
              selectedIndex: index,
              onDestinationSelected: controller.changeTab,
              destinations: const <NavigationDestination>[
                NavigationDestination(
                  icon: Icon(Icons.edit_note_outlined),
                  selectedIcon: Icon(Icons.edit_note),
                  label: 'AI',
                ),
                NavigationDestination(
                  icon: Icon(Icons.history_outlined),
                  selectedIcon: Icon(Icons.history),
                  label: '历史',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline_rounded),
                  selectedIcon: Icon(Icons.person_rounded),
                  label: '我的',
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}

class _ShellTabMeta {
  const _ShellTabMeta({
    required this.title,
    required this.icon,
    required this.tint,
    required this.supportTint,
  });

  final String title;
  final IconData icon;
  final Color tint;
  final Color supportTint;
}

class _HeaderModeButton extends StatelessWidget {
  const _HeaderModeButton({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.tune_rounded, size: 18, color: AppTheme.text),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.text,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
