import 'package:flutter/material.dart';
import 'package:get/get.dart';

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
      title: '创作视频',
      subtitle: '文案、提示词与任务提交',
      icon: Icons.auto_awesome_rounded,
      tint: Color(0xFF2F746A),
    ),
    _ShellTabMeta(
      title: '历史记录',
      subtitle: '查看状态、结果与下载',
      icon: Icons.history_toggle_off_rounded,
      tint: Color(0xFF4D80C9),
    ),
    _ShellTabMeta(
      title: '个人中心',
      subtitle: '账号信息与版本管理',
      icon: Icons.account_circle_outlined,
      tint: Color(0xFFD79B47),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Obx(() {
      final int index = controller.currentIndex.value;
      final _ShellTabMeta tab = _tabs[index];

      return Scaffold(
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: <Color>[
                        Colors.white.withValues(alpha: 0.74),
                        tab.tint.withValues(alpha: 0.08),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 22,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: tab.tint.withValues(alpha: 0.14),
                        ),
                        alignment: Alignment.center,
                        child: Icon(tab.icon, color: tab.tint, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              tab.title,
                              style: theme.textTheme.titleLarge,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              tab.subtitle,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
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
        bottomNavigationBar: SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(12, 6, 12, 12),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(28),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: NavigationBar(
              selectedIndex: index,
              onDestinationSelected: controller.changeTab,
              destinations: const <NavigationDestination>[
                NavigationDestination(
                  icon: Icon(Icons.edit_note_outlined),
                  selectedIcon: Icon(Icons.edit_note),
                  label: '创作',
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
    required this.subtitle,
    required this.icon,
    required this.tint,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color tint;
}
