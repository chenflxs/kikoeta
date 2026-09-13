import 'package:flutter/material.dart';

import '../data.dart';
import '../services/api_service.dart';
import '../theme.dart';

class AdvancedFilterPage extends StatefulWidget {
  final AppState app;

  const AdvancedFilterPage({super.key, required this.app});

  @override
  State<AdvancedFilterPage> createState() => _AdvancedFilterPageState();
}

class _AdvancedFilterPageState extends State<AdvancedFilterPage> {
  static const _tabs = <_AdvancedFilterTab>[
    _AdvancedFilterTab('声优', 'vas', '声优'),
    _AdvancedFilterTab('社团', 'circles', '社团'),
    _AdvancedFilterTab('标签', 'tags', '标签'),
  ];

  final _searchController = TextEditingController();
  final _entries = <String, List<AdvancedFilterEntry>>{};
  int _selectedTab = 0;
  bool _loading = false;
  String? _error;

  _AdvancedFilterTab get _tab => _tabs[_selectedTab];

  Palette get _palette => Theme.of(context).brightness == Brightness.dark
      ? AppColors.dark
      : AppColors.light;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadCurrentTab();
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _onSearchChanged() => setState(() {});

  Future<void> _loadCurrentTab({bool force = false}) async {
    final kind = _tab.kind;
    if (!force && _entries.containsKey(kind)) {
      setState(() {});
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final values = await ApiService.fetchAdvancedFilterEntries(
        widget.app,
        kind,
      );
      if (!mounted || kind != _tab.kind) return;
      setState(() {
        _entries[kind] = values;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || kind != _tab.kind) return;
      setState(() {
        _loading = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _selectTab(int index) {
    if (_selectedTab == index) return;
    setState(() {
      _selectedTab = index;
      _searchController.clear();
      _error = null;
    });
    _loadCurrentTab();
  }

  List<AdvancedFilterEntry> get _visibleEntries {
    final query = _searchController.text.trim().toLowerCase();
    final values = _entries[_tab.kind] ?? const <AdvancedFilterEntry>[];
    if (query.isEmpty) return values;
    return values
        .where((entry) => entry.name.toLowerCase().contains(query))
        .toList();
  }

  void _useEntry(AdvancedFilterEntry entry) {
    final token = switch (_tab.kind) {
      'vas' => r'$va:',
      'circles' => r'$circle:',
      _ => r'$tag:',
    };
    Navigator.of(context).pop();
    widget.app.requestSearch('$token${entry.name}\$');
  }

  @override
  Widget build(BuildContext context) {
    final p = _palette;
    return Scaffold(
      appBar: AppBar(
        title: const Text('高级筛选'),
        leading: const BackButton(),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTabs(p),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: _buildSearchField(p),
            ),
            Expanded(child: _buildContent(p)),
          ],
        ),
      ),
    );
  }

  Widget _buildTabs(Palette p) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < _tabs.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            _FilterTabButton(
              label: _tabs[i].label,
              selected: i == _selectedTab,
              onTap: () => _selectTab(i),
              palette: p,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchField(Palette p) {
    return TextField(
      controller: _searchController,
      style: TextStyle(color: p.text, fontSize: 13),
      decoration: InputDecoration(
        hintText: '搜索${_tab.placeholder}…',
        hintStyle: TextStyle(color: p.dim, fontSize: 13),
        prefixIcon: Icon(Icons.search, color: p.dim, size: 20),
        suffixIcon: _searchController.text.isEmpty
            ? null
            : IconButton(
                onPressed: _searchController.clear,
                icon: Icon(Icons.close, color: p.dim, size: 18),
              ),
        filled: true,
        fillColor: p.surface,
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide(color: p.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide(color: p.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide(color: p.accent),
        ),
      ),
    );
  }

  Widget _buildContent(Palette p) {
    if (_loading && !_entries.containsKey(_tab.kind)) {
      return Center(child: CircularProgressIndicator(color: p.accent));
    }
    if (_error != null && !_entries.containsKey(_tab.kind)) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_outlined, color: p.dim, size: 34),
              const SizedBox(height: 10),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: p.muted, fontSize: 13),
              ),
              const SizedBox(height: 14),
              OutlinedButton(
                onPressed: _loadCurrentTab,
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }
    final values = _visibleEntries;
    if (values.isEmpty) {
      return Center(
        child: Text(
          _searchController.text.isEmpty ? '暂无数据' : '没有匹配的参数',
          style: TextStyle(color: p.dim, fontSize: 13),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1100
            ? 4
            : constraints.maxWidth >= 760
            ? 3
            : constraints.maxWidth >= 480
            ? 2
            : 1;
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          itemCount: values.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisExtent: 48,
          ),
          itemBuilder: (context, index) {
            final entry = values[index];
            return _FilterEntryTile(
              entry: entry,
              palette: p,
              onTap: () => _useEntry(entry),
            );
          },
        );
      },
    );
  }
}

class _AdvancedFilterTab {
  final String label;
  final String kind;
  final String placeholder;

  const _AdvancedFilterTab(this.label, this.kind, this.placeholder);
}

class _FilterTabButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Palette palette;

  const _FilterTabButton({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? palette.accent : palette.surface,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? palette.accent : palette.line,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : palette.muted,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterEntryTile extends StatelessWidget {
  final AdvancedFilterEntry entry;
  final Palette palette;
  final VoidCallback onTap;

  const _FilterEntryTile({
    required this.entry,
    required this.palette,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: palette.surface,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: palette.line),
              right: BorderSide(color: palette.line),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  entry.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.text,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                constraints: const BoxConstraints(minWidth: 28),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: palette.accent.withValues(alpha: .16),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  '${entry.count}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: palette.accent,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
