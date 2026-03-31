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

  final List<String> _titles = <String>[
    '创建视频',
    '历史记录',
    '我的',
  ];

  final List<IconData> _icons = <IconData>[
    Icons.auto_awesome_rounded,
    Icons.history_toggle_off_rounded,
    Icons.account_circle_outlined,
  ];

  final List<List<Color>> _gradients = <List<Color>>[
    <Color>[const Color(0xFF2E7080), const Color(0xFFE18C49)],
    <Color>[const Color(0xFF3B6EA8), const Color(0xFF69A8A1)],
    <Color>[const Color(0xFF547A63), const Color(0xFFD2A24C)],
  ];

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Obx(() {
      final int index = controller.currentIndex.value;

      return Scaffold(
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 240),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _gradients[index],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          _titles[index],
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        alignment: Alignment.center,
                        child:
                            Icon(_icons[index], color: Colors.white, size: 26),
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
          minimum: const EdgeInsets.fromLTRB(14, 8, 14, 14),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: NavigationBar(
              selectedIndex: index,
              onDestinationSelected: controller.changeTab,
              destinations: const <NavigationDestination>[
                NavigationDestination(
                  icon: Icon(Icons.edit_note_outlined),
                  selectedIcon: Icon(Icons.edit_note),
                  label: '创建',
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
