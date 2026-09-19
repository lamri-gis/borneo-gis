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
  final String? focusId;
  final HighlightType? focusType;
  final bool isImport;
  final String? importFileId;

  const LayerDetailScreen({
    super.key,
    required this.layerId,
    this.focusId,
    this.focusType,
    this.isImport = false,
    this.importFileId,
  });

  @override
  State<LayerDetailScreen> createState() => _LayerDetailScreenState();
}

class _LayerDetailScreenState extends State<LayerDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    // Kalau dari import, buka tab Import (index 1), kalau original buka tab Original (index 0)
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.isImport ? 1 : 0);
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
            IconButton(
              icon: const Icon(Icons.upload_outlined, color: AppColors.warning),
              onPressed: () => _showExportMenu(context, lp, layer),
              tooltip: 'Export',
            ),
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
            _OriginalTab(
              layer: layer,
              layerId: widget.layerId,
              focusId: widget.isImport ? null : widget.focusId,
              focusType: widget.isImport ? null : widget.focusType,
            ),
            _ImportTab(
              layer: layer,
              layerId: widget.layerId,
              focusId: widget.isImport ? widget.focusId : null,
              focusType: widget.isImport ? widget.focusType : null,
              focusFileId: widget.importFileId,
            ),
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
          const Padding(padding: EdgeInsets.all(16), child: Text('Export', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600))),
          const Divider(height: 1, color: AppColors.divider),
          ListTile(
            leading: const Icon(Icons.folder_outlined, color: AppColors.primary),
            title: const Text('Original', style: TextStyle(color: AppColors.textPrimary)),
            onTap: () { Navigator.pop(context); _showOriginalExportMenu(context, layer); },
          ),
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
      final method = await _askExportMethod(context);
      if (method == null) return;
      final path = await KmlExporter.exportOriginal(layer: layer, type: type, fileName: name, method: method, context: context);
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
                final method = await _askExportMethod(context);
                if (method == null) return;
                final path = await KmlExporter.exportImport(importedFile: imp, type: type, fileName: name, method: method, context: context);
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

  Future<ExportMethod?> _askExportMethod(BuildContext context) async {
    return showDialog<ExportMethod>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Cara Export', style: TextStyle(color: AppColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.save_alt, color: AppColors.primary),
              title: const Text('Simpan ke penyimpanan', style: TextStyle(color: AppColors.textPrimary)),
              onTap: () => Navigator.pop(context, ExportMethod.save),
            ),
            ListTile(
              leading: const Icon(Icons.share, color: AppColors.accent),
              title: const Text('Kirim / Bagikan', style: TextStyle(color: AppColors.textPrimary)),
              subtitle: const Text('WhatsApp, Email, Bluetooth, dll', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
              onTap: () => Navigator.pop(context, ExportMethod.share),
            ),
          ],
        ),
      ),
    );
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
  final String? focusId;
  final HighlightType? focusType;

  const _OriginalTab({required this.layer, required this.layerId, this.focusId, this.focusType});

  @override
  State<_OriginalTab> createState() => _OriginalTabState();
}

class _OriginalTabState extends State<_OriginalTab> with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    // Auto pilih tab sesuai tipe objek yang difokus
    int initialIndex = 0;
    if (widget.focusType == HighlightType.track) initialIndex = 0;
    else if (widget.focusType == HighlightType.pin) initialIndex = 1;
    else if (widget.focusType == HighlightType.line) initialIndex = 2;
    else if (widget.focusType == HighlightType.polygon) initialIndex = 3;
    _tab = TabController(length: 4, vsync: this, initialIndex: initialIndex);
  }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final layer = widget.layer;
    return Column(
      children: [
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
              _TrackList(layer: layer, layerId: widget.layerId, focusId: widget.focusId),
              _PinList(layer: layer, layerId: widget.layerId, focusId: widget.focusId),
              _LineList(layer: layer, layerId: widget.layerId, focusId: widget.focusId),
              _PolygonList(layer: layer, layerId: widget.layerId, focusId: widget.focusId),
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

// ── ITEM LISTS ────────────────────────────────────────────────────────────────

class _TrackList extends StatelessWidget {
  final FieldLayer layer;
  final String layerId;
  final String? focusId;
  const _TrackList({required this.layer, required this.layerId, this.focusId});

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
          name: t.name, subtitle: t.distanceLabel, color: t.color, timestamp: t.createdAt,
          isFocused: focusId == t.id,
          onTap: () => _highlightAndPop(context, t.id, HighlightType.track),
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
  final String? focusId;
  const _PinList({required this.layer, required this.layerId, this.focusId});

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
          name: p.name, subtitle: '${p.latitude.toStringAsFixed(6)}°, ${p.longitude.toStringAsFixed(6)}°', color: p.color, timestamp: p.createdAt,
          isFocused: focusId == p.id,
          onTap: () => _highlightAndPop(context, p.id, HighlightType.pin),
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
  final String? focusId;
  const _LineList({required this.layer, required this.layerId, this.focusId});

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
          name: l.name, subtitle: l.distanceLabel, color: l.color, timestamp: l.createdAt,
          isFocused: focusId == l.id,
          onTap: () => _highlightAndPop(context, l.id, HighlightType.line),
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
  final String? focusId;
  const _PolygonList({required this.layer, required this.layerId, this.focusId});

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
          name: p.name, subtitle: p.areaLabel, color: p.color, timestamp: p.createdAt,
          isFocused: focusId == p.id,
          onTap: () => _highlightAndPop(context, p.id, HighlightType.polygon),
          onRename: (name) => context.read<LayerProvider>().renamePolygon(layerId, p.id, name),
          onColorChange: (c) => context.read<LayerProvider>().updatePolygonColor(layerId, p.id, c),
          onDelete: () => context.read<LayerProvider>().removePolygon(layerId, p.id),
        );
      },
    );
  }
}

void _highlightAndPop(BuildContext context, String id, HighlightType type, {String? fileId}) {
  context.read<LayerProvider>().setHighlightWithFile(id, type, fileId: fileId);
  Navigator.of(context).popUntil((route) => route.isFirst);
}

// ── IMPORT TAB ────────────────────────────────────────────────────────────────

class _ImportTab extends StatelessWidget {
  final FieldLayer layer;
  final String layerId;
  final String? focusId;
  final HighlightType? focusType;
  final String? focusFileId;

  const _ImportTab({required this.layer, required this.layerId, this.focusId, this.focusType, this.focusFileId});

  @override
  Widget build(BuildContext context) {
    if (layer.imports.isEmpty) return const _EmptyHint(label: 'Belum ada file import');
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: layer.imports.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _ImportFileCard(
        imp: layer.imports[i],
        layerId: layerId,
        focusId: focusFileId == layer.imports[i].id ? focusId : null,
        focusType: focusFileId == layer.imports[i].id ? focusType : null,
        autoExpand: focusFileId == layer.imports[i].id,
      ),
    );
  }
}

class _ImportFileCard extends StatefulWidget {
  final ImportedFile imp;
  final String layerId;
  final String? focusId;
  final HighlightType? focusType;
  final bool autoExpand;

  const _ImportFileCard({required this.imp, required this.layerId, this.focusId, this.focusType, this.autoExpand = false});

  @override
  State<_ImportFileCard> createState() => _ImportFileCardState();
}

class _ImportFileCardState extends State<_ImportFileCard> with SingleTickerProviderStateMixin {
  late TabController _tab;
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.autoExpand;
    int initialIndex = 0;
    if (widget.focusType == HighlightType.track) initialIndex = 0;
    else if (widget.focusType == HighlightType.pin) initialIndex = 1;
    else if (widget.focusType == HighlightType.line) initialIndex = 2;
    else if (widget.focusType == HighlightType.polygon) initialIndex = 3;
    _tab = TabController(length: 4, vsync: this, initialIndex: initialIndex);
  }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final imp = widget.imp;
    final lp = context.read<LayerProvider>();
    final isFileHighlighted = lp.highlightedFileId == imp.id;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isFileHighlighted ? AppColors.accent : AppColors.divider, width: isFileHighlighted ? 2 : 1),
      ),
      child: Column(
        children: [
          ListTile(
            leading: Icon(Icons.folder_zip_outlined, color: isFileHighlighted ? AppColors.accent : AppColors.textSecondary, size: 20),
            title: Text(imp.name, style: TextStyle(color: isFileHighlighted ? AppColors.accent : AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
            subtitle: Text('${imp.pins.length} pin  ${imp.tracks.length} track  ${imp.lines.length} line  ${imp.polygons.length} poly', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Highlight semua objek dalam file ini
                IconButton(
                  icon: const Icon(Icons.location_searching, color: AppColors.accent, size: 18),
                  onPressed: () {
                    // Highlight file -- kembali ke peta
                    lp.setHighlightWithFile(imp.id, HighlightType.track, fileId: imp.id);
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                ),
                IconButton(icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 18), onPressed: () => lp.removeImport(widget.layerId, imp.id)),
                IconButton(icon: Icon(_expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: AppColors.textSecondary, size: 18), onPressed: () => setState(() => _expanded = !_expanded)),
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
                  _ImportItemList(items: imp.tracks.map((t) => _ItemData(t.id, t.name, t.distanceLabel, t.color, t.createdAt, HighlightType.track)).toList(), layerId: widget.layerId, fileId: imp.id, focusId: widget.focusId),
                  _ImportItemList(items: imp.pins.map((p) => _ItemData(p.id, p.name, '${p.latitude.toStringAsFixed(5)}°, ${p.longitude.toStringAsFixed(5)}°', p.color, p.createdAt, HighlightType.pin)).toList(), layerId: widget.layerId, fileId: imp.id, focusId: widget.focusId),
                  _ImportItemList(items: imp.lines.map((l) => _ItemData(l.id, l.name, l.distanceLabel, l.color, l.createdAt, HighlightType.line)).toList(), layerId: widget.layerId, fileId: imp.id, focusId: widget.focusId),
                  _ImportItemList(items: imp.polygons.map((p) => _ItemData(p.id, p.name, p.areaLabel, p.color, p.createdAt, HighlightType.polygon)).toList(), layerId: widget.layerId, fileId: imp.id, focusId: widget.focusId),
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
  final String id, name, subtitle;
  final Color color;
  final DateTime createdAt;
  final HighlightType type;
  const _ItemData(this.id, this.name, this.subtitle, this.color, this.createdAt, this.type);
}

class _ImportItemList extends StatelessWidget {
  final List<_ItemData> items;
  final String layerId;
  final String fileId;
  final String? focusId;

  const _ImportItemList({required this.items, required this.layerId, required this.fileId, this.focusId});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const _EmptyHint(label: 'Kosong');
    return ListView.separated(
      padding: const EdgeInsets.all(8),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 4),
      itemBuilder: (_, i) {
        final item = items[i];
        final isFocused = focusId == item.id;
        return GestureDetector(
          onTap: () => _highlightAndPop(context, item.id, item.type, fileId: fileId),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isFocused ? AppColors.accent.withOpacity(0.15) : AppColors.background,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: isFocused ? AppColors.accent : Colors.transparent),
            ),
            child: Row(children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: item.color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item.name, style: TextStyle(color: isFocused ? AppColors.accent : AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
                Text(item.subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10)),
              ])),
              const Icon(Icons.location_searching, color: AppColors.accent, size: 14),
            ]),
          ),
        );
      },
    );
  }
}

// ── SHARED WIDGETS ────────────────────────────────────────────────────────────

class _ItemCard extends StatelessWidget {
  final String name, subtitle;
  final Color color;
  final DateTime timestamp;
  final bool isFocused;
  final VoidCallback onTap;
  final Function(String) onRename;
  final Function(Color) onColorChange;
  final VoidCallback onDelete;

  const _ItemCard({required this.name, required this.subtitle, required this.color, required this.timestamp, required this.onTap, required this.onRename, required this.onColorChange, required this.onDelete, this.isFocused = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isFocused ? AppColors.primary.withOpacity(0.1) : AppColors.card,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isFocused ? AppColors.primary : AppColors.divider, width: isFocused ? 2 : 1),
        ),
        child: Row(
          children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: TextStyle(color: isFocused ? AppColors.primary : AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
              Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10)),
              Text(_formatTs(timestamp), style: const TextStyle(color: AppColors.textSecondary, fontSize: 9)),
            ])),
            IconButton(icon: const Icon(Icons.edit_outlined, color: AppColors.textSecondary, size: 16), onPressed: () => _rename(context)),
            IconButton(icon: const Icon(Icons.palette_outlined, color: AppColors.textSecondary, size: 16), onPressed: () => _pickColor(context)),
            IconButton(icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 16), onPressed: onDelete),
          ],
        ),
      ),
    );
  }

  String _formatTs(DateTime dt) => '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}/${dt.year}  ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';

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
  Widget build(BuildContext context) => Center(child: Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)));
}
