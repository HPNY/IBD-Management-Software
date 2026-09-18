import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/identity/local_identity.dart';
import 'home/dashboard_tab.dart';
import 'injection/injection_page.dart';
import 'settings/settings_page.dart';
import 'symptom/symptom_page.dart';

/// 底部导航：首页 · 打卡 · 注射 · 我的
class ShellPage extends StatefulWidget {
  const ShellPage({super.key});

  @override
  State<ShellPage> createState() => _ShellPageState();
}

class _ShellPageState extends State<ShellPage> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final identity = context.watch<LocalIdentity>();
    final pages = [
      DashboardTab(onOpen: _goTab),
      const SymptomPage(embedded: true),
      const InjectionPage(embedded: true),
      SettingsPage(embedded: true, syncOn: identity.syncOptIn),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: '首页',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_outline_rounded),
            selectedIcon: Icon(Icons.favorite_rounded),
            label: '打卡',
          ),
          NavigationDestination(
            icon: Icon(Icons.vaccines_outlined),
            selectedIcon: Icon(Icons.vaccines_rounded),
            label: '注射',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: '我的',
          ),
        ],
      ),
    );
  }

  void _goTab(int i) => setState(() => _index = i);
}
