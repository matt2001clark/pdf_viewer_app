import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

const accent = Color(0xFF2450D6);
const ink = Color(0xFF16181D);
const muted = Color(0xFF5B6270);
const border = Color(0xFFD9DCE3);
const ground = Color(0xFFF4F5F7);

void main() => runApp(const PdfViewerApp());

class PdfViewerApp extends StatelessWidget {
  const PdfViewerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PDF Viewer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: accent),
        scaffoldBackgroundColor: ground,
      ),
      home: const LibraryScreen(),
    );
  }
}

class RecentDoc {
  RecentDoc(this.path);
  final String path;
  int pageCount = 0;
  int lastPage = 1;
  String get name => path.split(RegExp(r'[\\/]')).last;
}

// ---------------------------------------------------------------- Library

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final List<RecentDoc> _docs = [];
  String _query = '';
  int _filter = 0; // visual only for now: Recent / Favorites / All files

  
  Future<void> _pick() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (files.isEmpty) return;

    final path = files.first.path;
    if (path == null) return;

    var doc = _docs.where((d) => d.path == path).firstOrNull;

    if (doc == null) {
      doc = RecentDoc(path);
      _docs.insert(0, doc);
    }

    await _open(doc);
  }


  Future<void> _open(RecentDoc doc) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ReaderScreen(doc: doc)),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final shown = _docs
        .where((d) => d.name.toLowerCase().contains(_query.toLowerCase()))
        .toList();
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _pick,
        backgroundColor: accent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Open PDF',
            style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Library',
                  style: TextStyle(
                      fontSize: 28, fontWeight: FontWeight.w600, color: ink)),
              const SizedBox(height: 16),
              TextField(
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Search documents',
                  prefixIcon: const Icon(Icons.search, color: muted),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: EdgeInsets.zero,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: accent),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  for (final (i, label) in ['Recent', 'Favorites', 'All files']
                      .indexed)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(label),
                        selected: _filter == i,
                        showCheckmark: false,
                        selectedColor: ink,
                        backgroundColor: Colors.white,
                        labelStyle: TextStyle(
                            color: _filter == i ? Colors.white : ink,
                            fontWeight: FontWeight.w500),
                        shape: StadiumBorder(
                            side: BorderSide(
                                color: _filter == i ? ink : border)),
                        onSelected: (_) => setState(() => _filter = i),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: shown.isEmpty
                    ? const Center(
                        child: Text('No PDFs yet. Tap Open PDF to start.',
                            style: TextStyle(color: muted)))
                    : ListView.builder(
                        itemCount: shown.length,
                        itemBuilder: (_, i) => _DocRow(
                            doc: shown[i], onTap: () => _open(shown[i])),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DocRow extends StatelessWidget {
  const _DocRow({required this.doc, required this.onTap});
  final RecentDoc doc;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: border),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(Icons.picture_as_pdf_outlined, color: muted),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(doc.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: ink)),
                  const SizedBox(height: 4),
                  Text(
                      doc.pageCount > 0
                          ? '${doc.pageCount} pages'
                          : 'Not opened yet',
                      style: const TextStyle(fontSize: 13, color: muted)),
                ],
              ),
            ),
            Text('Page ${doc.lastPage}',
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500, color: accent)),
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------- Reader

class ReaderScreen extends StatefulWidget {
  const ReaderScreen({super.key, required this.doc});
  final RecentDoc doc;

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  final _controller = PdfViewerController();
  final _viewerKey = GlobalKey<SfPdfViewerState>();
  final _bookmarks = <int>{};
  late int _page = widget.doc.lastPage;
  late int _total = widget.doc.pageCount;
  bool _fullscreen = false;

  void _setFullscreen(bool value) {
    setState(() => _fullscreen = value);
    SystemChrome.setEnabledSystemUIMode(
      value ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
    );
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _search() async {
    final text = TextEditingController();
    final query = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Search'),
        content: TextField(
          controller: text,
          autofocus: true,
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, text.text),
              child: const Text('Search')),
        ],
      ),
    );
    if (query != null && query.isNotEmpty) _controller.searchText(query);
  }

  @override
  Widget build(BuildContext context) {
    final marked = _bookmarks.contains(_page);
    return PopScope(
      canPop: !_fullscreen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _setFullscreen(false);
      },
      child: Scaffold(
      appBar: _fullscreen
          ? null
          : AppBar(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              title: Text(widget.doc.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600)),
              actions: [
                IconButton(
                  tooltip: 'Full screen',
                  icon: const Icon(Icons.fullscreen),
                  onPressed: () => _setFullscreen(true),
                ),
              ],
            ),
      body: SfPdfViewer.file(
        File(widget.doc.path),
        key: _viewerKey,
        controller: _controller,
        onTap: (details) {
          if (_fullscreen) _setFullscreen(false);
        },
        onDocumentLoaded: (details) {
          setState(() {
            _total = details.document.pages.count;
            widget.doc.pageCount = _total;
          });
          if (widget.doc.lastPage > 1) {
            _controller.jumpToPage(widget.doc.lastPage);
          }
        },
        onPageChanged: (details) {
          setState(() => _page = details.newPageNumber);
          widget.doc.lastPage = details.newPageNumber;
        },
      ),
      bottomNavigationBar: _fullscreen ? null : Material(
        color: Colors.white,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Slider(
                        min: 1,
                        max: _total > 1 ? _total.toDouble() : 2,
                        divisions: _total > 1 ? _total - 1 : null,
                        value: _page.clamp(1, _total > 1 ? _total : 2).toDouble(),
                        activeColor: accent,
                        onChanged: (v) => _controller.jumpToPage(v.round()),
                      ),
                    ),
                    Text('$_page / $_total',
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _ToolButton(
                        icon: Icons.search, label: 'Search', onTap: _search),
                    _ToolButton(
                        icon: Icons.format_list_bulleted,
                        label: 'Contents',
                        onTap: () =>
                            _viewerKey.currentState?.openBookmarkView()),
                    _ToolButton(
                      icon: marked ? Icons.bookmark : Icons.bookmark_border,
                      label: 'Bookmark',
                      onTap: () => setState(() => marked
                          ? _bookmarks.remove(_page)
                          : _bookmarks.add(_page)),
                    ),
                    _ToolButton(
                        icon: Icons.fit_screen,
                        label: 'Fit width',
                        onTap: () => _controller.zoomLevel = 1.0),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ));
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton(
      {required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 72,
        height: 52,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: const Color(0xFF3F4652)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(fontSize: 12, color: Color(0xFF3F4652))),
          ],
        ),
      ),
    );
  }
}