import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/layer_provider.dart';
import '../models/layer_models.dart';
import '../theme/app_theme.dart';
import '../utils/kml_importer.dart';
import '../utils/kml_exporter.dart';

class LayerDetailScreen extends StatefulWidget {
  final String layerId;
  const LayerDetailScreen({super.key, required this.layerId});

  @override
  State<LayerDetailScreen> createState() => _LayerDetailScreenState();
}

class _LayerDetailScreenState extends State<LayerDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Selection mode
  bool _selectMode = false;
  final Set<String> _selected = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  FieldLayer _layer(LayerProvider lp) => lp.layers.firstWhere((l) => l.id == widget.layerId);

  @override
  Widget build(BuildContext context) {
    return Consumer<LayerProvider>(builder: (_, lp, __) {
      final layer = _layer(lp);
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          title: Text(layer.name, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
          iconTheme: const IconThemeData(color: AppColors.textPrimary),
          elevation: 0,
          actions: [
            // Export
            IconButton(
              icon: const Icon(Icons.upload_outlined, color: AppColors.warning),
              onPressed: () => _showExportMenu(context, lp, layer),
              tooltip: 'Export',
            ),
            // Import
            IconButton(
              icon: const Icon(Icons.download_outlined, color: AppColors.accent),
              onPressed: () => _importFile(context, lp, layer),
              tooltip: 'Import KML',
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            tabs: const [Tab(text: 'ORIGINAL'), Tab(text: 'IMPORT')],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _OriginalTab(layer: layer, layerId: widget.layerId),
            _ImportTab(layer: layer, layerId: widget.layerId),
          ],
        ),
      );
    });
  }

  Future<void> _importFile(BuildContext context, LayerProvider lp, FieldLayer layer) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['kml', 'KML']);
    if (result == null || result.files.isEmpty) return;
    final path = result.files.first.path;
    if (path == null) return;
    final imported = await KmlImporter.parse(path);
    if (imported == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal import file')));
      return;
    }
    await lp.addImport(layer.id, imported);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Import: ${imported.name}')));
  }

  void _showExportMenu(BuildContext context, LayerProvider lp, FieldLayer layer) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Export', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
          ),
          const Divider(height: 1, color: AppColors.divider),
          // Original
          ListTile(
            leading: const Icon(Icons.folder_outlined, color: AppColors.primary),
            title: const Text('Original', style: TextStyle(color: AppColors.textPrimary)),
            onTap: () { Navigator.pop(context); _showOriginalExportMenu(context, layer); },
          ),
          // Import
          if (layer.imports.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.folder_zip_outlined, color: AppColors.accent),
              title: const Text('Import', style: TextStyle(color: AppColors.textPrimary)),
              onTap: () { Navigator.pop(context); _showImportExportMenu(context, layer); },
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _showOriginalExportMenu(BuildContext context, FieldLayer layer) {
    _showExportTypeMenu(context, 'Original', (type) async {
      final ctrl = TextEditingController(text: layer.name);
      final name = await _askFileName(context, ctrl);
      if (name == null) return;
      final path = await KmlExporter.exportOriginal(layer: layer, type: type, fileName: name);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(path != null ? 'Disimpan: $path' : 'Export dibatalkan')));
    });
  }

  void _showImportExportMenu(BuildContext context, FieldLayer layer) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(padding: EdgeInsets.all(16), child: Text('Pilih File Import', style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600))),
          ...layer.imports.map((imp) => ListTile(
            leading: const Icon(Icons.insert_drive_file_outlined, color: AppColors.accent),
            title: Text(imp.name, style: const TextStyle(color: AppColors.textPrimary)),
            onTap: () {
              Navigator.pop(context);
              _showExportTypeMenu(context, imp.name, (type) async {
                final ctrl = TextEditingController(text: imp.name);
                final name = await _askFileName(context, ctrl);
                if (name == null) return;
                final path = await KmlExporter.exportImport(importedFile: imp, type: type, fileName: name);
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(path != null ? 'Disimpan: $path' : 'Export dibatalkan')));
              });
            },
          )),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _showExportTypeMenu(BuildContext context, String title, Function(ExportType) onSelect) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(padding: const EdgeInsets.all(16), child: Text('Export $title', style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600))),
          ...ExportType.values.map((t) => ListTile(
            leading: const Icon(Icons.save_alt, color: AppColors.primary),
            title: Text(_exportTypeLabel(t), style: const TextStyle(color: AppColors.textPrimary)),
            onTap: () { Navigator.pop(context); onSelect(t); },
          )),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  String _exportTypeLabel(ExportType t) {
    switch (t) {
      case ExportType.all: return 'Export All (Pin + Track + Line + Poligon)';
      case ExportType.track: return 'Export Track saja';
      case ExportType.pin: return 'Export Pin saja';
      case ExportType.line: return 'Export Line saja';
      case ExportType.polygon: return 'Export Poligon saja';
    }
  }

  Future<String?> _askFileName(BuildContext context, TextEditingController ctrl) async {
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Nama File', style: TextStyle(color: AppColors.textPrimary)),
        content: TextField(controller: ctrl, style: const TextStyle(color: AppColors.textPrimary), decoration: const InputDecoration(labelText: 'Nama file (.kml)')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          ElevatedButton(onPressed: () => Navigator.pop(context, ctrl.text), child: const Text('OK')),
        ],
      ),
    );
  }
}

// ── ORIGINAL TAB ──────────────────────────────────────────────────────────────

class _OriginalTab extends StatefulWidget {
  final FieldLayer layer;
  final String layerId;
  const _OriginalTab({required this.layer, required this.layerId});

  @override
  State<_OriginalTab> createState() => _OriginalTabState();
}

class _OriginalTabState extends State<_OriginalTab> with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final layer = widget.layer;
    return Column(
      children: [
        // Section header + bulk delete
        Container(
          color: AppColors.surface,
          child: Row(
            children: [
              Expanded(
                child: TabBar(
                  controller: _tab,
                  isScrollable: true,
                  indicatorColor: AppColors.primary,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textSecondary,
                  labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  tabs: [
                    Tab(text: 'Track (${layer.tracks.length})'),
                    Tab(text: 'Pin (${layer.pins.length})'),
                    Tab(text: 'Line (${layer.lines.length})'),
                    Tab(text: 'Poly (${layer.polygons.length})'),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: AppColors.textSecondary, size: 18),
                color: AppColors.card,
                onSelected: (val) => _bulkDelete(context, val),
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'track', child: Text('Hapus semua Track', style: TextStyle(color: AppColors.textPrimary))),
                  const PopupMenuItem(value: 'pin', child: Text('Hapus semua Pin', style: TextStyle(color: AppColors.textPrimary))),
                  const PopupMenuItem(value: 'line', child: Text('Hapus semua Line', style: TextStyle(color: AppColors.textPrimary))),
                  const PopupMenuItem(value: 'polygon', child: Text('Hapus semua Poligon', style: TextStyle(color: AppColors.textPrimary))),
                  const PopupMenuItem(value: 'all', child: Text('Hapus semua Original', style: TextStyle(color: AppColors.error))),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [
              _TrackList(layer: layer, layerId: widget.layerId),
              _PinList(layer: layer, layerId: widget.layerId),
              _LineList(layer: layer, layerId: widget.layerId),
              _PolygonList(layer: layer, layerId: widget.layerId),
            ],
          ),
        ),
      ],
    );
  }

  void _bulkDelete(BuildContext context, String type) {
    final lp = context.read<LayerProvider>();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Konfirmasi Hapus', style: TextStyle(color: AppColors.textPrimary)),
        content: Text('Hapus semua ${type == 'all' ? 'Original' : type}?', style: const TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              switch (type) {
                case 'track': lp.removeAllTracks(widget.layerId); break;
                case 'pin': lp.removeAllPins(widget.layerId); break;
                case 'line': lp.removeAllLines(widget.layerId); break;
                case 'polygon': lp.removeAllPolygons(widget.layerId); break;
                case 'all': lp.removeAllOriginal(widget.layerId); break;
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _TrackList extends StatelessWidget {
  final FieldLayer layer;
  final String layerId;
  const _TrackList({required this.layer, required this.layerId});

  @override
  Widget build(BuildContext context) {
    if (layer.tracks.isEmpty) return const _EmptyHint(label: 'Belum ada track');
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: layer.tracks.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (_, i) {
        final t = layer.tracks[i];
        return _ItemCard(
          name: t.name,
          subtitle: t.distanceLabel,
          color: t.color,
          timestamp: t.createdAt,
          onRename: (name) => context.read<LayerProvider>().renameTrack(layerId, t.id, name),
          onColorChange: (c) => context.read<LayerProvider>().updateTrackColor(layerId, t.id, c),
          onDelete: () => context.read<LayerProvider>().removeTrack(layerId, t.id),
        );
      },
    );
  }
}

class _PinList extends StatelessWidget {
  final FieldLayer layer;
  final String layerId;
  const _PinList({required this.layer, required this.layerId});

  @override
  Widget build(BuildContext context) {
    if (layer.pins.isEmpty) return const _EmptyHint(label: 'Belum ada pin');
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: layer.pins.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (_, i) {
        final p = layer.pins[i];
        return _ItemCard(
          name: p.name,
          subtitle: '${p.latitude.toStringAsFixed(6)}°, ${p.longitude.toStringAsFixed(6)}°',
          color: p.color,
          timestamp: p.createdAt,
          onRename: (name) => context.read<LayerProvider>().renamePin(layerId, p.id, name),
          onColorChange: (c) => context.read<LayerProvider>().updatePinColor(layerId, p.id, c),
          onDelete: () => context.read<LayerProvider>().removePin(layerId, p.id),
        );
      },
    );
  }
}

class _LineList extends StatelessWidget {
  final FieldLayer layer;
  final String layerId;
  const _LineList({required this.layer, required this.layerId});

  @override
  Widget build(BuildContext context) {
    if (layer.lines.isEmpty) return const _EmptyHint(label: 'Belum ada line');
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: layer.lines.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (_, i) {
        final l = layer.lines[i];
        return _ItemCard(
          name: l.name,
          subtitle: l.distanceLabel,
          color: l.color,
          timestamp: l.createdAt,
          onRename: (name) => context.read<LayerProvider>().renameLine(layerId, l.id, name),
          onColorChange: (c) => context.read<LayerProvider>().updateLineColor(layerId, l.id, c),
          onDelete: () => context.read<LayerProvider>().removeLine(layerId, l.id),
        );
      },
    );
  }
}

class _PolygonList extends StatelessWidget {
  final FieldLayer layer;
  final String layerId;
  const _PolygonList({required this.layer, required this.layerId});

  @override
  Widget build(BuildContext context) {
    if (layer.polygons.isEmpty) return const _EmptyHint(label: 'Belum ada poligon');
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: layer.polygons.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (_, i) {
        final p = layer.polygons[i];
        return _ItemCard(
          name: p.name,
          subtitle: p.areaLabel,
          color: p.color,
          timestamp: p.createdAt,
          onRename: (name) => context.read<LayerProvider>().renamePolygon(layerId, p.id, name),
          onColorChange: (c) => context.read<LayerProvider>().updatePolygonColor(layerId, p.id, c),
          onDelete: () => context.read<LayerProvider>().removePolygon(layerId, p.id),
        );
      },
    );
  }
}

// ── IMPORT TAB ────────────────────────────────────────────────────────────────

class _ImportTab extends StatelessWidget {
  final FieldLayer layer;
  final String layerId;
  const _ImportTab({required this.layer, required this.layerId});

  @override
  Widget build(BuildContext context) {
    if (layer.imports.isEmpty) return const _EmptyHint(label: 'Belum ada file import');
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: layer.imports.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final imp = layer.imports[i];
        return _ImportFileCard(imp: imp, layerId: layerId);
      },
    );
  }
}

class _ImportFileCard extends StatefulWidget {
  final ImportedFile imp;
  final String layerId;
  const _ImportFileCard({required this.imp, required this.layerId});

  @override
  State<_ImportFileCard> createState() => _ImportFileCardState();
}

class _ImportFileCardState extends State<_ImportFileCard> with SingleTickerProviderStateMixin {
  late TabController _tab;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final imp = widget.imp;
    return Container(
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.divider)),
      child: Column(
        children: [
          // Header
          ListTile(
            leading: const Icon(Icons.folder_zip_outlined, color: AppColors.accent, size: 20),
            title: Text(imp.name, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
            subtitle: Text('${imp.pins.length} pin  ${imp.tracks.length} track  ${imp.lines.length} line  ${imp.polygons.length} poly', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 18),
                  onPressed: () => context.read<LayerProvider>().removeImport(widget.layerId, imp.id),
                ),
                IconButton(
                  icon: Icon(_expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: AppColors.textSecondary, size: 18),
                  onPressed: () => setState(() => _expanded = !_expanded),
                ),
              ],
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1, color: AppColors.divider),
            TabBar(
              controller: _tab,
              isScrollable: true,
              indicatorColor: AppColors.accent,
              labelColor: AppColors.accent,
              unselectedLabelColor: AppColors.textSecondary,
              labelStyle: const TextStyle(fontSize: 11),
              tabs: [
                Tab(text: 'Track (${imp.tracks.length})'),
                Tab(text: 'Pin (${imp.pins.length})'),
                Tab(text: 'Line (${imp.lines.length})'),
                Tab(text: 'Poly (${imp.polygons.length})'),
              ],
            ),
            SizedBox(
              height: 200,
              child: TabBarView(
                controller: _tab,
                children: [
                  _ImportItemList(items: imp.tracks.map((t) => _ItemData(t.name, t.distanceLabel, t.color, t.createdAt)).toList()),
                  _ImportItemList(items: imp.pins.map((p) => _ItemData(p.name, '${p.latitude.toStringAsFixed(5)}°, ${p.longitude.toStringAsFixed(5)}°', p.color, p.createdAt)).toList()),
                  _ImportItemList(items: imp.lines.map((l) => _ItemData(l.name, l.distanceLabel, l.color, l.createdAt)).toList()),
                  _ImportItemList(items: imp.polygons.map((p) => _ItemData(p.name, p.areaLabel, p.color, p.createdAt)).toList()),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ItemData {
  final String name, subtitle;
  final Color color;
  final DateTime createdAt;
  const _ItemData(this.name, this.subtitle, this.color, this.createdAt);
}

class _ImportItemList extends StatelessWidget {
  final List<_ItemData> items;
  const _ImportItemList({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const _EmptyHint(label: 'Kosong');
    return ListView.separated(
      padding: const EdgeInsets.all(8),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 4),
      itemBuilder: (_, i) {
        final item = items[i];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(6)),
          child: Row(
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: item.color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name, style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
                  Text(item.subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10)),
                ],
              )),
            ],
          ),
        );
      },
    );
  }
}

// ── SHARED WIDGETS ────────────────────────────────────────────────────────────

class _ItemCard extends StatelessWidget {
  final String name;
  final String subtitle;
  final Color color;
  final DateTime timestamp;
  final Function(String) onRename;
  final Function(Color) onColorChange;
  final VoidCallback onDelete;

  const _ItemCard({required this.name, required this.subtitle, required this.color, required this.timestamp, required this.onRename, required this.onColorChange, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.divider)),
      child: Row(
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
                Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10)),
                Text(_formatTs(timestamp), style: const TextStyle(color: AppColors.textSecondary, fontSize: 9)),
              ],
            ),
          ),
          // Edit nama
          IconButton(icon: const Icon(Icons.edit_outlined, color: AppColors.textSecondary, size: 16), onPressed: () => _rename(context)),
          // Ganti warna
          IconButton(icon: const Icon(Icons.palette_outlined, color: AppColors.textSecondary, size: 16), onPressed: () => _pickColor(context)),
          // Hapus
          IconButton(icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 16), onPressed: onDelete),
        ],
      ),
    );
  }

  String _formatTs(DateTime dt) {
    return '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}/${dt.year}  ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
  }

  void _rename(BuildContext context) {
    final ctrl = TextEditingController(text: name);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Ubah Nama', style: TextStyle(color: AppColors.textPrimary)),
        content: TextField(controller: ctrl, style: const TextStyle(color: AppColors.textPrimary), decoration: const InputDecoration(labelText: 'Nama baru')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          ElevatedButton(onPressed: () { onRename(ctrl.text); Navigator.pop(context); }, child: const Text('Simpan')),
        ],
      ),
    );
  }

  void _pickColor(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Pilih Warna', style: TextStyle(color: AppColors.textPrimary)),
        content: Wrap(
          spacing: 12, runSpacing: 12,
          children: LayerColors.options.map((c) => GestureDetector(
            onTap: () { onColorChange(c); Navigator.pop(context); },
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: Border.all(color: c == color ? AppColors.primary : AppColors.divider, width: c == color ? 3 : 1)),
              child: c == color ? const Icon(Icons.check, size: 18, color: Colors.black) : null,
            ),
          )).toList(),
        ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final String label;
  const _EmptyHint({required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(child: Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)));
  }
}
