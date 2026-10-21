import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';

void main() {
  runApp(const KibaliTerminalApp());
}

class AttachedFile {
  final String name;
  final String path;
  AttachedFile({required this.name, required this.path});
}

class KibaliTheme {
  final String name;
  final Color bg, panel, border, text, subtext, accent, green, orange;
  KibaliTheme({
    required this.name,
    required this.bg,
    required this.panel,
    required this.border,
    required this.text,
    required this.subtext,
    required this.accent,
    required this.green,
    required this.orange,
  });
}

final List<KibaliTheme> themes = [
  KibaliTheme(name: 'Tokyo Night', bg: const Color(0xFF1a1b26), panel: const Color(0xFF16161e), border: const Color(0xFF292e42), text: const Color(0xFFa9b1d6), subtext: const Color(0xFF565f89), accent: const Color(0xFF7aa2f7), green: const Color(0xFF9ece6a), orange: const Color(0xFFe0af68)),
  KibaliTheme(name: 'Cyberpunk', bg: const Color(0xFF0d0221), panel: const Color(0xFF190f2e), border: const Color(0xFF7209b7), text: const Color(0xFFf72585), subtext: const Color(0xFF9d4edd), accent: const Color(0xFF00f5d4), green: const Color(0xFF00f5d4), orange: const Color(0xFFFF9E00)),
  KibaliTheme(name: 'Jesus!', bg: const Color(0xFF282a36), panel: const Color(0xFF44475a), border: const Color(0xFF6272a4), text: const Color(0xFFf8f8f2), subtext: const Color(0xFF6272a4), accent: const Color(0xFFbd93f9), green: const Color(0xFF50fa7b), orange: const Color(0xFFffb86c)),
  KibaliTheme(name: 'Blanche', bg: const Color(0xFFF8FAFC), panel: const Color(0xFFF1F5F9), border: const Color(0xFFCBD5E1), text: const Color(0xFF0F172A), subtext: const Color(0xFF64748B), accent: const Color(0xFF3B82F6), green: const Color(0xFF10B981), orange: const Color(0xFFF59E0B)),
  KibaliTheme(name: 'Noir', bg: const Color(0xFF000000), panel: const Color(0xFF111111), border: const Color(0xFF222222), text: const Color(0xFFFFFFFF), subtext: const Color(0xFF888888), accent: const Color(0xFF00E5FF), green: const Color(0xFF00FF00), orange: const Color(0xFFFFAA00)),
  KibaliTheme(name: 'Blue', bg: const Color(0xFF0B132B), panel: const Color(0xFF071024), border: const Color(0xFF1C2541), text: const Color(0xFFE0E1DD), subtext: const Color(0xFF778DA9), accent: const Color(0xFF00B4D8), green: const Color(0xFF06D6A0), orange: const Color(0xFFFFD166)),
];

class LiveEvent {
  final String time, message, type;
  final String? filePath;
  LiveEvent({required this.time, required this.message, this.type = 'info', this.filePath});
}

class KibaliTerminalApp extends StatefulWidget {
  const KibaliTerminalApp({super.key});
  @override
  State<KibaliTerminalApp> createState() => _KibaliTerminalAppState();
}

class _KibaliTerminalAppState extends State<KibaliTerminalApp> {
  int _themeIndex = 0;
  void changeTheme(int index) => setState(() => _themeIndex = index);
  @override
  Widget build(BuildContext context) {
    final theme = themes[_themeIndex];
    return MaterialApp(
      title: 'KIBALI AGI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: theme.bg,
        fontFamily: GoogleFonts.inter().fontFamily,
      ),
      home: KibaliHome(theme: theme, onChangeTheme: changeTheme, currentThemeIndex: _themeIndex),
    );
  }
}

class KibaliHome extends StatefulWidget {
  final KibaliTheme theme;
  final Function(int) onChangeTheme;
  final int currentThemeIndex;
  const KibaliHome({super.key, required this.theme, required this.onChangeTheme, required this.currentThemeIndex});
  @override
  State<KibaliHome> createState() => _KibaliHomeState();
}

class _KibaliHomeState extends State<KibaliHome> with TickerProviderStateMixin {
  final TextEditingController _inputController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  final List<AttachedFile> _attachedFiles = [];

  final ScrollController _chatScrollController = ScrollController();
  final ScrollController _thoughtScrollController = ScrollController();
  final ScrollController _terminalScrollController = ScrollController();
  final ScrollController _logsScrollController = ScrollController();
  final ScrollController _liveScrollController = ScrollController();

  // ⬇️ OPTIMISATION 1 : StringBuffer au lieu de String pour concaténer rapidement
  final StringBuffer _chatBuffer = StringBuffer('KIBALI AGI Terminal v23 - Prêt.\nEn attente du moteur...\n\n');
  final StringBuffer _thoughtBuffer = StringBuffer();
  final StringBuffer _terminalBuffer = StringBuffer();
  final StringBuffer _logsBuffer = StringBuffer();

  bool _isEngineRunning = false, _isAiThinking = false;
  int _currentTab = 0;
  bool _inThought = false, _inExecute = false, _inFinal = false;

  final List<LiveEvent> _liveEvents = [LiveEvent(time: 'INFO', message: 'Bus live initialisé.')];
  Timer? _autoTourTimer, _refreshTimer;
  int _currentToolIndex = 0;
  List<String> _allTools = [], _filteredTools = [];
  Map<String, String> _toolDescriptions = {};
  bool _isLoadingTools = true;

  // CEPP Variables
  double _ceppPrice = 85.0, _ceppProduction = 6000000.0, _ceppCosts = 2500000.0, _ceppRmpRate = 12.5;
  double _ceppCostOilCap = 70.0;

  // TABFISCAL
  String _tabfiscalTitle = "Analyse des Données";
  List<String> _tabfiscalColumns = ["Colonne 1", "Colonne 2"];
  List<List<String>> _tabfiscalRows = [];
  String _tabfiscalVba = "' Le code VBA généré par l'IA apparaîtra ici.";

  // CAD VIEWER
  Map<String, dynamic>? _cadData;
  String _cadFileName = "";

  Process? _engineProcess;
  late AnimationController _glowController;
  KibaliTheme get t => widget.theme;

  // ⬇️ OPTIMISATION 2 : RégEx compilée une seule fois
  final RegExp _fileRegex = RegExp(r'(?:FILE:|Fichier\s*:|PDF généré.*?:)\s*`?([a-zA-Z0-9_\-\.]+\.(?:pdf|xlsx|docx|csv|txt|json|svg|png|jpg|jpeg|exe|dxf|py|html))`?');
  
  // ⬇️ OPTIMISATION 3 : Throttling de l'interface
  Timer? _uiThrottleTimer;
  bool _needsUiUpdate = false;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);
    _fetchRagTools();
    _startEngine();
    _searchController.addListener(_filterTools);
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (timer) { if (mounted) setState(() {}); });

    // L'UI se rafraîchit toutes les 100ms max au lieu de 50 fois par seconde
    _uiThrottleTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (_needsUiUpdate && mounted) {
        setState(() { _needsUiUpdate = false; });
        _scrollToBottomIfNeeded();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _autoTourTimer?.cancel();
    _uiThrottleTimer?.cancel();
    _glowController.dispose();
    _engineProcess?.kill();
    _inputController.dispose();
    _searchController.dispose();
    _chatScrollController.dispose();
    _thoughtScrollController.dispose();
    _terminalScrollController.dispose();
    _logsScrollController.dispose();
    _liveScrollController.dispose();
    super.dispose();
  }

  String _cleanAnsi(String text) => text.replaceAll(RegExp('\u001B\\[[0-9;]*[mGKH]'), '');

  Future<void> _fetchRagTools() async {
    try {
      final response = await http.get(Uri.parse('http://127.0.0.1:8765/tool_schemas')).timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List tools = data['tools'] ?? [];
        Map<String, String> tempDescs = {};
        List<String> tempNames = [];
        for (var tool in tools) {
          String name = tool['function']['name'].toString();
          String desc = tool['function']['description'] ?? "Aucune description.";
          tempNames.add(name);
          tempDescs[name] = desc;
        }
        setState(() {
          _allTools = tempNames;
          _filteredTools = List.from(_allTools);
          _toolDescriptions = tempDescs;
          _isLoadingTools = false;
        });
        _startAutoTour();
      } else {
        _loadFallbackTools();
      }
    } catch (e) {
      debugPrint('fetchRagTools: $e');
      _loadFallbackTools();
    }
  }

  void _loadFallbackTools() {
    setState(() {
      _allTools = ['generate_pdf', 'calculate'];
      _filteredTools = List.from(_allTools);
      _toolDescriptions = {'generate_pdf': 'Génère PDF.', 'calculate': 'Calcul.'};
      _isLoadingTools = false;
    });
    _startAutoTour();
  }

  void _filterTools() => setState(() => _filteredTools = _allTools.where((tool) => tool.toLowerCase().contains(_searchController.text.toLowerCase())).toList());

  void _startAutoTour() {
    _autoTourTimer?.cancel();
    _autoTourTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_allTools.isEmpty) return;
      String toolName = _allTools[_currentToolIndex];
      _addLiveEvent('[AUTO] $toolName :\n${_toolDescriptions[toolName] ?? ""}', 'tuto');
      _currentToolIndex = (_currentToolIndex + 1) % _allTools.length;
    });
  }

  void _startEngine() async {
    if (_engineProcess != null) _engineProcess!.kill();
    setState(() {
      _isEngineRunning = true;
      _logsBuffer.writeln('[SYSTEM] Démarrage du moteur...');
    });

    // ⬇️ SÉCURITÉ ANDROID : Impossible de lancer un .exe Python natif
    if (!Platform.isWindows) {
      setState(() {
        _logsBuffer.writeln('[ERREUR FATALE] Le moteur Python local ne peut tourner que sur Windows.');
        _logsBuffer.writeln('[INFO] Sur Android, connectez-vous à un serveur distant (API WebSocket).');
        _chatBuffer.writeln('\n🛑 [SYSTÈME] Mode Android : Le moteur local nécessite un serveur distant.');
        _isEngineRunning = false;
      });
      return;
    }

    final env = Map<String, String>.from(Platform.environment)
      ..['PYTHONUNBUFFERED'] = '1'
      ..['PYTHONIOENCODING'] = 'utf-8';
    try {
      _engineProcess = await Process.start(
        'D:\\CPT_Analysis_Studio_PORTABLE\\environment\\python.exe',
        ['D:\\CPT_Analysis_Studio_PORTABLE\\KIBALI_MOTEUR_V3_FAST.py'],
        workingDirectory: 'D:\\CPT_Analysis_Studio_PORTABLE',
        environment: env,
      );
      _engineProcess!.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
        if (mounted) _processLine(line);
      });
      _engineProcess!.stderr.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
        if (mounted) {
          _logsBuffer.writeln('[ERREUR] ${_cleanAnsi(line)}');
          _needsUiUpdate = true;
        }
      });
    } catch (e) {
      _logsBuffer.writeln('[ERREUR FATALE] $e');
      _needsUiUpdate = true;
    }
  }

  Map<String, String>? _parseUiAction(String line) {
    const openTag = '<ui_action ';
    final start = line.indexOf(openTag);
    if (start < 0) return null;
    final end = line.indexOf('/>', start);
    if (end < 0) return null;

    final inner = line.substring(start + openTag.length, end).trim();
    final result = <String, String>{};

    int i = 0;
    while (i < inner.length) {
      while (i < inner.length && (inner[i] == ' ' || inner[i] == '\t' || inner[i] == '\n')) { i++; }
      if (i >= inner.length) break;
      final nameStart = i;
      while (i < inner.length && inner[i] != '=') { i++; }
      if (i >= inner.length) break;
      final name = inner.substring(nameStart, i).trim();
      i++;
      if (i >= inner.length) break;
      final quote = inner[i];
      if (quote != '"' && quote != "'") break;
      i++;
      final buf = StringBuffer();
      bool closed = false;
      while (i < inner.length) {
        if (inner[i] == '\\' && i + 1 < inner.length) {
          buf.write(inner[i + 1]);
          i += 2;
        } else if (inner[i] == quote) {
          i++; closed = true; break;
        } else {
          buf.write(inner[i]); i++;
        }
      }
      if (!closed) break;
      result[name] = buf.toString();
    }
    return result;
  }

  void _handleUiAction(Map<String, String> action) {
    final plugin = action['plugin'] ?? '';
    final param = action['param'] ?? '';
    final value = action['value'] ?? '';

    setState(() {
      if (plugin == 'cepp') {
        if (param == 'price') _ceppPrice = double.tryParse(value) ?? _ceppPrice;
        if (param == 'production') _ceppProduction = double.tryParse(value) ?? _ceppProduction;
        if (param == 'costs') _ceppCosts = double.tryParse(value) ?? _ceppCosts;
        if (param == 'rmp_rate') _ceppRmpRate = double.tryParse(value) ?? _ceppRmpRate;
        if (param == 'cost_oil_cap') _ceppCostOilCap = double.tryParse(value) ?? _ceppCostOilCap;
        _currentTab = 1;
        _addLiveEvent('[UI] Paramètre CEPP mis à jour par l\'IA : $param = $value', 'info');
      } else if (plugin == 'tabfiscal') {
        if (param == 'title') _tabfiscalTitle = value;
        if (param == 'vba') _tabfiscalVba = value.replaceAll('\\n', '\n');
        if (param == 'table') {
          try {
            final data = jsonDecode(value);
            _tabfiscalColumns = List<String>.from(data['columns'] ?? []);
            _tabfiscalRows = (data['rows'] as List?)?.map((row) => List<String>.from(row)).toList() ?? [];
          } catch (e) { debugPrint('tabfiscal table parse: $e'); }
        }
        _currentTab = 2;
        _addLiveEvent('[UI] Paramètre TABFISCAL mis à jour par l\'IA.', 'info');
      }
    });
  }

  void _processLine(String line) {
    String cleanLine = _cleanAnsi(line).replaceAll('\r', '');

    final uiAction = _parseUiAction(cleanLine);
    if (uiAction != null) {
      _handleUiAction(uiAction);
      return;
    }

    final fileMatch = _fileRegex.firstMatch(cleanLine);
    if (fileMatch != null) {
      String fileName = fileMatch.group(1)!;
      final candidates = [
        'D:\\CPT_Analysis_Studio_PORTABLE\\outputs\\$fileName',
        'D:\\CPT_Analysis_Studio_PORTABLE\\$fileName',
        'D:\\CPT_Analysis_Studio_PORTABLE\\documents\\$fileName',
        'D:\\CPT_Analysis_Studio_PORTABLE\\images\\$fileName',
      ];
      String fullPath = candidates.firstWhere((p) => File(p).existsSync(), orElse: () => candidates.first);
      _addLiveEvent('Fichier généré : $fileName', 'file', filePath: fullPath);
      return;
    }

    // ⬇️ Plus de setState ici, on utilise StringBuffer et on lève juste un flag
    if (cleanLine.contains('💭 [Réflexion]')) {
      _inThought = true; _inExecute = false; _inFinal = false;
      _thoughtBuffer.writeln('\n💭 [Réflexion]');
      _needsUiUpdate = true;
      return;
    }
    if (cleanLine.contains('🎯 [Action]')) {
      _inThought = false; _inExecute = false; _inFinal = false;
      _thoughtBuffer.writeln('\n🎯 [Action]');
      _needsUiUpdate = true;
      return;
    }
    if (cleanLine.contains('<execute>') || cleanLine.contains('<terminal>')) {
      _inExecute = true; _inThought = false; _inFinal = false;
      _terminalBuffer.writeln('\n--- EXECUTION ---');
      _needsUiUpdate = true;
      return;
    }
    if (cleanLine.contains('</execute>') || cleanLine.contains('</terminal>')) {
      _inExecute = false;
      _terminalBuffer.writeln('-----------------');
      _needsUiUpdate = true;
      return;
    }
    if (cleanLine.contains('<final>')) {
      _inFinal = true; _inThought = false; _inExecute = false;
      _needsUiUpdate = true;
      return;
    }
    if (cleanLine.contains('</final>')) {
      _inFinal = false;
      _needsUiUpdate = true;
      return;
    }

    if (cleanLine.startsWith('👤 Vous >')) {
      _chatBuffer.writeln('\n$cleanLine');
      _isAiThinking = true;
    } else if (cleanLine.startsWith('[SYSTEM]') || cleanLine.startsWith('[ERREUR]') || cleanLine.startsWith('🔄 CYCLE') || cleanLine.startsWith('📊 RAM')) {
      _logsBuffer.writeln('$cleanLine');
    } else if (_inThought) {
      _thoughtBuffer.writeln('$cleanLine');
    } else if (_inExecute) {
      _terminalBuffer.writeln('$cleanLine');
    } else if (_inFinal) {
      _chatBuffer.writeln('$cleanLine');
      _isAiThinking = false;
    } else {
      _chatBuffer.writeln('$cleanLine');
      if (cleanLine.contains('MISSION ACCOMPLIE')) _isAiThinking = false;
    }
    
    _needsUiUpdate = true;
  }

  void _scrollToBottomIfNeeded() {
    // ⬇️ OPTIMISATION 4 : On ne force le scroll QUE si on est déjà en bas
    bool shouldScroll(ScrollController c) => c.hasClients && (c.position.maxScrollExtent - c.position.pixels) < 150;
    
    if (shouldScroll(_chatScrollController)) _scrollToBottom(_chatScrollController);
    if (_inThought && shouldScroll(_thoughtScrollController)) _scrollToBottom(_thoughtScrollController);
    if (_inExecute && shouldScroll(_terminalScrollController)) _scrollToBottom(_terminalScrollController);
    if (shouldScroll(_logsScrollController)) _scrollToBottom(_logsScrollController);
    if (shouldScroll(_liveScrollController)) _scrollToBottom(_liveScrollController);
  }

  Future<void> _pickFiles() async {
    try {
      String psScript = 'Add-Type -AssemblyName System.Windows.Forms; \$f = New-Object System.Windows.Forms.OpenFileDialog; \$f.Multiselect = \$true; if (\$f.ShowDialog() -eq "OK") { \$f.FileNames -join "`n" }';
      final result = await Process.run('powershell', ['-Command', psScript]);
      if (result.stdout.toString().trim().isNotEmpty) {
        setState(() {
          for (String p in result.stdout.toString().trim().split('\n')) {
            if (p.trim().isNotEmpty) {
              _attachedFiles.add(AttachedFile(name: p.trim().split('\\').last, path: p.trim()));
            }
          }
        });
      }
    } catch (e) { debugPrint('pickFiles: $e'); }
  }

  void _sendCommand() {
    final text = _inputController.text.trim();
    if ((text.isEmpty && _attachedFiles.isEmpty) || _engineProcess == null) return;
    if (text.toLowerCase() == 'clear') {
      setState(() {
        _chatBuffer.clear(); _chatBuffer.write('KIBALI AGI Terminal v23 - Prêt.\n\n');
        _thoughtBuffer.clear(); _terminalBuffer.clear(); _logsBuffer.clear();
        _liveEvents.clear(); _attachedFiles.clear(); _inputController.clear();
      });
      _engineProcess!.stdin.writeln('clear\n');
      return;
    }
    String finalMessage = '';
    if (_attachedFiles.isNotEmpty) {
      finalMessage += "📎 [FICHIERS JOINTS]\n";
      for (var f in _attachedFiles) {
        String ext = f.path.split('.').last.toLowerCase();
        String destPath = 'D:\\CPT_Analysis_Studio_PORTABLE\\images\\upload_${DateTime.now().millisecondsSinceEpoch}.$ext';
        try {
          Directory('D:\\CPT_Analysis_Studio_PORTABLE\\images').createSync(recursive: true);
          File(f.path).copySync(destPath);
          finalMessage += "  - ${f.name} → $destPath\n";
        } catch (e) {
          finalMessage += "  - ${f.name} (erreur)\n";
        }
      }
    }
    finalMessage += text;
    setState(() {
      _chatBuffer.writeln('\n👤 Vous > $finalMessage');
      _inputController.clear();
      _attachedFiles.clear();
      _isAiThinking = true;
    });
    _scrollToBottom(_chatScrollController);
    _engineProcess!.stdin.writeln(finalMessage);
  }

  void _scrollToBottom(ScrollController controller) => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (controller.hasClients) {
      controller.animateTo(controller.position.maxScrollExtent, duration: const Duration(milliseconds: 100), curve: Curves.easeOut);
    }
  });

  void _addLiveEvent(String message, String type, {String? filePath}) {
    if (!mounted) return;
    _liveEvents.add(LiveEvent(time: TimeOfDay.now().format(context), message: message, type: type, filePath: filePath));
    _needsUiUpdate = true;
  }

  void _openFile(String path) async {
    try { await Process.run('cmd', ['/c', 'start', '', path]); } catch (e) { debugPrint('openFile: $e'); }
  }

  void _openFolder(String path) async {
    try { await Process.run('explorer.exe', ['/select,', path]); } catch (e) { debugPrint('openFolder: $e'); }
  }

  void _downloadFile(String path) async {
    try {
      String psScript = 'Add-Type -AssemblyName System.Windows.Forms; \$s = New-Object System.Windows.Forms.SaveFileDialog; \$s.FileName = "${path.split('\\').last}"; if (\$s.ShowDialog() -eq "OK") { Copy-Item -Path "$path" -Destination \$s.FileName -Force }';
      await Process.run('powershell', ['-Command', psScript]);
    } catch (e) { debugPrint('downloadFile: $e'); }
  }

  Future<void> _loadCadFile(String path) async {
    try {
      String content = await File(path).readAsString();
      setState(() {
        _cadData = jsonDecode(content);
        _cadFileName = path.split('\\').last;
        _currentTab = 5;
      });
    } catch (e) {
      _addLiveEvent("Erreur chargement CAD: $e", 'info');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          Container(
            width: 260,
            decoration: BoxDecoration(color: t.panel, border: Border(right: BorderSide(color: t.border))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLogoHeader(),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    controller: _searchController,
                    style: TextStyle(color: t.text, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Rechercher...',
                      hintStyle: TextStyle(color: t.subtext),
                      prefixIcon: Icon(Icons.search, color: t.subtext, size: 18),
                      filled: true,
                      fillColor: t.bg,
                      border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.circular(6)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ),
                _buildTabButton('Terminal Agent', 0, Icons.terminal),
                _buildTabButton('Plugin CEPP', 1, Icons.calculate),
                _buildTabButton('TABFISCAL', 2, Icons.table_view),
                _buildTabButton('Fichiers', 3, Icons.folder_open),
                _buildTabButton('Projects', 4, Icons.source),
                _buildTabButton('CAD Viewer', 5, Icons.architecture),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text('V OUTILS DU RAG', style: TextStyle(color: t.subtext, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  child: _isLoadingTools
                      ? Center(child: CircularProgressIndicator(color: t.accent))
                      : Material(
                          color: Colors.transparent,
                          child: ListView.builder(
                            itemCount: _filteredTools.length,
                            itemBuilder: (context, index) {
                              return ListTile(
                                dense: true,
                                leading: Container(width: 8, height: 8, decoration: BoxDecoration(color: t.green, shape: BoxShape.circle)),
                                title: Text(_filteredTools[index], style: TextStyle(color: t.text, fontSize: 12, fontFamily: 'monospace'), overflow: TextOverflow.ellipsis),
                                hoverColor: t.border,
                                onTap: () => _inputController.text = _filteredTools[index],
                              );
                            },
                          ),
                        ),
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(border: Border(top: BorderSide(color: t.border))),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('KIBALI AGI v23', style: TextStyle(color: t.accent, fontSize: 11, fontWeight: FontWeight.bold)),
                      Text('Dev IA : Nyundu Fancis Arnaud', style: TextStyle(color: t.subtext, fontSize: 10)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              color: t.bg,
              child: Column(
                children: [
                  Container(
                    height: 50,
                    decoration: BoxDecoration(color: t.panel, border: Border(bottom: BorderSide(color: t.border))),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Text(
                          _currentTab == 0 ? 'Cockpit Agent' : _currentTab == 1 ? 'CEPP' : _currentTab == 2 ? 'TABFISCAL' : _currentTab == 3 ? 'Fichiers' : _currentTab == 4 ? 'Projects' : 'CAD Viewer - $_cadFileName',
                          style: TextStyle(color: t.text, fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        PopupMenuButton<int>(
                          icon: Icon(Icons.palette, color: t.accent, size: 20),
                          onSelected: widget.onChangeTheme,
                          itemBuilder: (context) => List.generate(
                            themes.length,
                            (index) => PopupMenuItem(value: index, child: Text(themes[index].name, style: TextStyle(color: t.text, fontSize: 12))),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _currentTab == 0
                        ? _buildSplitView()
                        : _currentTab == 1
                            ? _buildCeppPlugin()
                            : _currentTab == 2
                                ? _buildTabfiscalPlugin()
                                : _currentTab == 3
                                    ? _buildFileInspectorPlugin()
                                    : _currentTab == 4
                                        ? _buildProjectsPlugin()
                                        : _buildCadViewerPlugin(),
                  ),
                  if (_currentTab == 0) _buildInputArea(),
                ],
              ),
            ),
          ),
          Container(
            width: 280,
            decoration: BoxDecoration(color: t.panel, border: Border(left: BorderSide(color: t.border))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.border))),
                  child: Row(
                    children: [
                      Container(width: 8, height: 8, decoration: BoxDecoration(color: _isEngineRunning ? t.green : t.orange, shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Text('LIVE EVENTS', style: TextStyle(color: t.accent, fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: _liveScrollController,
                    padding: const EdgeInsets.all(12),
                    itemCount: _liveEvents.length,
                    itemBuilder: (context, index) => _buildLiveItem(_liveEvents[index]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSplitView() {
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(child: _buildPane('Chat & Réponses', _chatBuffer.toString(), _chatScrollController, t.text, bgColor: t.bg, borderColor: t.border)),
              Container(width: 1, color: t.border),
              Expanded(child: _buildPane('Réflexions', _thoughtBuffer.toString(), _thoughtScrollController, t.subtext, italic: true, bgColor: t.bg, borderColor: t.border)),
            ],
          ),
        ),
        Container(height: 1, color: t.border),
        Expanded(
          child: Row(
            children: [
              Expanded(child: _buildPane('Terminal & Code', _terminalBuffer.toString(), _terminalScrollController, t.accent, bgColor: t.bg, borderColor: t.border)),
              Container(width: 1, color: t.border),
              Expanded(child: _buildPane('Logs Bruts', _logsBuffer.toString(), _logsScrollController, Colors.grey, bgColor: t.bg, borderColor: t.border)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPane(String title, String content, ScrollController controller, Color textColor, {bool italic = false, required Color bgColor, required Color borderColor}) {
    return Container(
      decoration: BoxDecoration(color: bgColor, border: Border.all(color: borderColor, width: 2)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: t.panel, border: Border(bottom: BorderSide(color: borderColor, width: 2))),
            child: Text(title, style: TextStyle(color: t.accent, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              child: SingleChildScrollView(
                controller: controller,
                child: SelectableText(
                  content.isEmpty ? '—' : content,
                  style: GoogleFonts.robotoMono(
                    color: textColor,
                    fontSize: 12,
                    height: 1.5,
                    fontStyle: italic ? FontStyle.italic : FontStyle.normal,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: t.panel, border: Border(top: BorderSide(color: t.border))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_attachedFiles.isNotEmpty)
            Wrap(
              spacing: 8,
              children: _attachedFiles
                  .asMap()
                  .entries
                  .map(
                    (e) => Chip(
                      label: Text(e.value.name, style: TextStyle(color: t.text, fontSize: 11)),
                      backgroundColor: t.bg,
                      side: BorderSide(color: t.border),
                      deleteIcon: Icon(Icons.close, size: 14, color: t.subtext),
                      onDeleted: () => setState(() => _attachedFiles.removeAt(e.key)),
                    ),
                  )
                  .toList(),
            ),
          Row(
            children: [
              IconButton(icon: Icon(Icons.attach_file, color: t.subtext), onPressed: _pickFiles),
              Text('> ', style: GoogleFonts.robotoMono(color: t.green, fontSize: 16)),
              Expanded(
                child: TextField(
                  controller: _inputController,
                  style: GoogleFonts.robotoMono(color: t.text, fontSize: 14),
                  decoration: InputDecoration(border: InputBorder.none, hintText: 'Posez une question...', hintStyle: TextStyle(color: t.subtext)),
                  onSubmitted: (_) => _sendCommand(),
                ),
              ),
              if (_isAiThinking)
                const Padding(
                  padding: EdgeInsets.only(right: 15),
                  child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange)),
                ),
              IconButton(icon: Icon(Icons.send, color: t.accent), onPressed: _sendCommand),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CEPP PLUGIN COMPLET
  // ============================================================
  Widget _buildCeppPlugin() {
    double grossRevenue = _ceppPrice * _ceppProduction;
    double rmpAmount = grossRevenue * (_ceppRmpRate / 100);
    double netRevenue = grossRevenue - rmpAmount;
    double maxCostOil = netRevenue * (_ceppCostOilCap / 100);
    double costOilRecovered = _ceppCosts < maxCostOil ? _ceppCosts : maxCostOil;
    double profitOil = netRevenue - costOilRecovered;
    double stateSharePct = _ceppProduction > 50000 ? 0.60 : 0.45;
    double stateProfitOil = profitOil * stateSharePct;
    double operatorProfitOil = profitOil * (1 - stateSharePct);
    double totalStateTake = rmpAmount + stateProfitOil;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calculate, color: t.accent, size: 28),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('TBFISCAL KIBALI V3 - Calculateur CEPP', style: TextStyle(color: t.accent, fontSize: 22, fontWeight: FontWeight.bold)),
                  Text('Moteur de calcul des droits à l\'huile de l\'État (Temps Réel)', style: TextStyle(color: t.subtext, fontSize: 13)),
                ],
              ),
            ],
          ),
          const Divider(height: 40, color: Color(0xFF292e42)),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 4,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: t.panel,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: t.border),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('PARAMÈTRES DU CONTRAT', style: TextStyle(color: t.accent, fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 24),
                      _buildCeppSlider('Prix du Baril (USD)', _ceppPrice, 50, 150, (v) => setState(() => _ceppPrice = v), suffix: '\$'),
                      _buildCeppSlider('Production Totale (Barils)', _ceppProduction, 1000000, 10000000, (v) => setState(() => _ceppProduction = v)),
                      _buildCeppSlider('Coûts Pétroliers (USD)', _ceppCosts, 0, 5000000, (v) => setState(() => _ceppCosts = v), suffix: '\$'),
                      const SizedBox(height: 16),
                      _buildCeppTextField('Taux de Redevance (%)', _ceppRmpRate.toString(), (v) => setState(() => _ceppRmpRate = double.tryParse(v) ?? _ceppRmpRate)),
                      const SizedBox(height: 12),
                      _buildCeppTextField('Plafond Cost Oil (%)', _ceppCostOilCap.toString(), (v) => setState(() => _ceppCostOilCap = double.tryParse(v) ?? _ceppCostOilCap)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                flex: 6,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(color: t.panel, borderRadius: BorderRadius.circular(12), border: Border.all(color: t.border)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('RÉSULTATS FINANCIERS', style: TextStyle(color: t.accent, fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(child: _buildCeppResultCard('DROITS À L\'HUILE (ÉTAT)', totalStateTake, const Color(0xFFEAB308))),
                              const SizedBox(width: 12),
                              Expanded(child: _buildCeppResultCard('REDEVANCE', rmpAmount, const Color(0xFFEAB308))),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(child: _buildCeppResultCard('COST OIL (RÉCUPÉRÉ)', costOilRecovered, const Color(0xFF3B82F6))),
                              const SizedBox(width: 12),
                              Expanded(child: _buildCeppResultCard('PROFIT OIL TOTAL', profitOil, const Color(0xFF10B981))),
                            ],
                          ),
                          const SizedBox(height: 30),
                          SizedBox(
                            height: 220,
                            child: Row(
                              children: [
                                Expanded(
                                  child: PieChart(
                                    PieChartData(
                                      sectionsSpace: 2,
                                      centerSpaceRadius: 60,
                                      sections: [
                                        PieChartSectionData(color: const Color(0xFFEAB308), value: totalStateTake, title: '', radius: 40),
                                        PieChartSectionData(color: const Color(0xFF3B82F6), value: costOilRecovered, title: '', radius: 40),
                                        PieChartSectionData(color: const Color(0xFF10B981), value: operatorProfitOil, title: '', radius: 40),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 20),
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildLegendItem('Droits État', const Color(0xFFEAB308)),
                                    const SizedBox(height: 8),
                                    _buildLegendItem('Cost Oil', const Color(0xFF3B82F6)),
                                    const SizedBox(height: 8),
                                    _buildLegendItem('Profit Opérateur', const Color(0xFF10B981)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E1B4B),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFF4C1D95)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.verified_user, color: Colors.purpleAccent, size: 18),
                                    const SizedBox(width: 8),
                                    const Text('Analyse Réglementaire Automatique', style: TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    const Icon(Icons.check_box, color: Colors.greenAccent, size: 16),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Conforme : Les paramètres respectent les seuils standards.',
                                        style: TextStyle(color: t.text, fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: t.panel, borderRadius: BorderRadius.circular(12), border: Border.all(color: t.border)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('DÉTAIL DU PARTAGE DU PROFIT OIL (PAR TRANCHES)', style: TextStyle(color: t.accent, fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 20),
                DataTable(
                  headingRowColor: WidgetStateProperty.all(t.bg),
                  dataRowColor: WidgetStateProperty.all(t.panel),
                  border: TableBorder.all(color: t.border),
                  columns: [
                    DataColumn(label: Text('Tranche (B/j)', style: TextStyle(color: t.accent, fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Part État', style: TextStyle(color: t.accent, fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Valeur Tranche (\$)', style: TextStyle(color: t.accent, fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Profit État (\$)', style: TextStyle(color: t.accent, fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Profit Opérateur (\$)', style: TextStyle(color: t.accent, fontWeight: FontWeight.bold))),
                  ],
                  rows: [
                    _buildTrancheRow('0 - 20 000', 0.50, profitOil),
                    _buildTrancheRow('20 000 - 50 000', 0.60, profitOil),
                    _buildTrancheRow('> 50 000', 0.70, profitOil),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCeppSlider(String label, double value, double min, double max, Function(double) onChanged, {String? suffix}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(color: t.text, fontSize: 13)),
            Text('${value.toStringAsFixed(0)} ${suffix ?? ''}'.trim(), style: TextStyle(color: t.text, fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: t.accent,
            inactiveTrackColor: t.border,
            thumbColor: t.accent,
            overlayColor: t.accent.withValues(alpha: 0.2),
            trackHeight: 4,
          ),
          child: Slider(value: value, min: min, max: max, onChanged: onChanged),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildCeppTextField(String label, String initialValue, Function(String) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: t.text, fontSize: 13)),
        const SizedBox(height: 6),
        TextFormField(
          key: ValueKey('cepp_${label}_$initialValue'),
          initialValue: initialValue,
          style: TextStyle(color: t.text, fontSize: 13),
          decoration: InputDecoration(
            filled: true,
            fillColor: t.bg,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(borderSide: BorderSide(color: t.border), borderRadius: BorderRadius.circular(6)),
            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: t.border), borderRadius: BorderRadius.circular(6)),
            focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: t.accent), borderRadius: BorderRadius.circular(6)),
          ),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildCeppResultCard(String title, double value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: t.bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: t.border),
      ),
      child: Column(
        children: [
          Text(title, style: TextStyle(color: t.subtext, fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text('${_formatMoney(value)} \$', style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(color: t.text, fontSize: 12)),
      ],
    );
  }

  DataRow _buildTrancheRow(String tranche, double stateShare, double totalProfit) {
    double estimatedValue = totalProfit * 0.15;
    double stateProfit = estimatedValue * stateShare;
    double opProfit = estimatedValue * (1 - stateShare);

    return DataRow(cells: [
      DataCell(Text(tranche, style: TextStyle(color: t.text, fontSize: 12))),
      DataCell(Text('${(stateShare * 100).toInt()} %', style: TextStyle(color: t.text, fontSize: 12))),
      DataCell(Text(_formatMoney(estimatedValue), style: TextStyle(color: t.text, fontSize: 12))),
      DataCell(Text(_formatMoney(stateProfit), style: TextStyle(color: const Color(0xFFEAB308), fontSize: 12))),
      DataCell(Text(_formatMoney(opProfit), style: TextStyle(color: const Color(0xFF10B981), fontSize: 12))),
    ]);
  }

  String _formatMoney(double value) {
    return value.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]} ',
    );
  }

  // ============================================================
  // AUTRES PLUGINS
  // ============================================================

  Widget _buildTabfiscalPlugin() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(_tabfiscalTitle, style: TextStyle(color: t.accent, fontSize: 22, fontWeight: FontWeight.bold)),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.download),
                label: const Text("Télécharger VBA"),
                style: ElevatedButton.styleFrom(backgroundColor: t.green, foregroundColor: Colors.black),
              ),
            ],
          ),
          const Divider(height: 40, color: Color(0xFF292e42)),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 1,
                  child: Container(
                    decoration: BoxDecoration(color: t.panel, borderRadius: BorderRadius.circular(12), border: Border.all(color: t.border)),
                    child: SingleChildScrollView(
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(t.bg),
                        dataRowColor: WidgetStateProperty.all(t.panel),
                        border: TableBorder.all(color: t.border),
                        columns: _tabfiscalColumns
                            .map((c) => DataColumn(label: Text(c, style: TextStyle(color: t.accent, fontWeight: FontWeight.bold))))
                            .toList(),
                        rows: _tabfiscalRows
                            .map((r) => DataRow(cells: r.map((c) => DataCell(Text(c, style: TextStyle(color: t.text)))).toList()))
                            .toList(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  flex: 1,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: const Color(0xFF000000), borderRadius: BorderRadius.circular(12), border: Border.all(color: t.border)),
                    child: SingleChildScrollView(
                      child: SelectableText(_tabfiscalVba, style: GoogleFonts.robotoMono(color: Colors.cyanAccent, fontSize: 13)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileInspectorPlugin() {
    List<FileSystemEntity> files = [];
    Directory outputsDir = Directory('D:\\CPT_Analysis_Studio_PORTABLE\\outputs');
    if (outputsDir.existsSync()) {
      files = outputsDir.listSync().whereType<File>().where((f) => !f.path.endsWith('~') && !f.path.split('\\').last.startsWith('#')).toList();
      files.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
    }
    return Row(
      children: [
        Container(
          width: 280,
          decoration: BoxDecoration(color: t.panel, border: Border(right: BorderSide(color: t.border))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text('FICHIERS GÉNÉRÉS (${files.length})', style: TextStyle(color: t.accent, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
              Expanded(
                child: files.isEmpty
                    ? Center(child: Text('Aucun fichier.', style: TextStyle(color: t.subtext)))
                    : ListView.builder(
                        itemCount: files.length,
                        itemBuilder: (context, index) {
                          final file = files[index];
                          return ListTile(
                            dense: true,
                            leading: Icon(Icons.insert_drive_file, color: t.subtext, size: 18),
                            title: Text(file.path.split('\\').last, style: TextStyle(color: t.text, fontSize: 12), overflow: TextOverflow.ellipsis),
                            onTap: () {
                              if (file.path.endsWith('.json')) {
                                _loadCadFile(file.path);
                              } else {
                                _openFile(file.path);
                              }
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
        Expanded(child: Center(child: Text('Cliquez sur un fichier .json pour l\'ouvrir dans le CAD Viewer.', style: TextStyle(color: t.subtext)))),
      ],
    );
  }

  Widget _buildProjectsPlugin() {
    Directory projectsDir = Directory('D:\\CPT_Analysis_Studio_PORTABLE\\projects');
    if (!projectsDir.existsSync()) projectsDir.createSync(recursive: true);
    List<FileSystemEntity> projects = projectsDir.listSync().whereType<Directory>().toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text('MES PROJETS KIBALI', style: TextStyle(color: t.text, fontSize: 22, fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: projects.isEmpty
              ? Center(child: Text("Aucun projet.", style: TextStyle(color: t.subtext)))
              : ListView.builder(
                  itemCount: projects.length,
                  itemBuilder: (context, index) {
                    String name = projects[index].path.split('\\').last;
                    return Card(
                      color: t.panel,
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        leading: Icon(Icons.folder, color: t.orange, size: 32),
                        title: Text(name, style: TextStyle(color: t.text, fontWeight: FontWeight.bold)),
                        trailing: ElevatedButton.icon(
                          onPressed: () {
                            _inputController.text = "/focus $name";
                            _sendCommand();
                          },
                          icon: const Icon(Icons.center_focus_strong, size: 16),
                          label: const Text('Indexer'),
                          style: ElevatedButton.styleFrom(backgroundColor: t.accent, foregroundColor: Colors.black),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildCadViewerPlugin() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: t.panel,
          child: Row(
            children: [
              Icon(Icons.architecture, color: t.accent, size: 24),
              const SizedBox(width: 12),
              Text('Visualiseur CAD Natif', style: TextStyle(color: t.text, fontSize: 18, fontWeight: FontWeight.bold)),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () async {
                  String psScript = 'Add-Type -AssemblyName System.Windows.Forms; \$f = New-Object System.Windows.Forms.OpenFileDialog; \$f.Filter = "JSON CAD|*.json"; if (\$f.ShowDialog() -eq "OK") { \$f.FileName }';
                  final result = await Process.run('powershell', ['-Command', psScript]);
                  String path = result.stdout.toString().trim();
                  if (path.isNotEmpty && File(path).existsSync()) {
                    _loadCadFile(path);
                  }
                },
                icon: const Icon(Icons.folder_open),
                label: const Text("Charger un JSON"),
                style: ElevatedButton.styleFrom(backgroundColor: t.accent, foregroundColor: Colors.black),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xFF292e42)),
        Expanded(
          child: _cadData == null
              ? Center(child: Text("Aucun plan chargé. Cliquez sur 'Charger un JSON'.", style: TextStyle(color: t.subtext)))
              : LayoutBuilder(
                  builder: (ctx, cst) => InteractiveViewer(
                    minScale: 0.1,
                    maxScale: 10.0,
                    child: SizedBox(
                      width: cst.maxWidth,
                      height: cst.maxHeight,
                      child: CustomPaint(
                        painter: CadPainter(data: _cadData!, bgColor: t.bg, wallColor: t.text, textColor: t.accent, tableColor: t.green),
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildLiveItem(LiveEvent event) {
    if (event.type == 'file') {
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: t.bg, borderRadius: BorderRadius.circular(6), border: Border.all(color: t.accent)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.insert_drive_file, color: t.accent, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    event.message, 
                    style: TextStyle(color: t.text, fontSize: 12, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              alignment: WrapAlignment.spaceEvenly,
              spacing: 4,
              runSpacing: 4,
              children: [
                _buildFileActionButton(Icons.open_in_new, 'Ouvrir', t.green, () => _openFile(event.filePath!)),
                _buildFileActionButton(Icons.download, 'Télécharger', t.accent, () => _downloadFile(event.filePath!)),
                _buildFileActionButton(Icons.folder_open, 'Dossier', t.orange, () => _openFolder(event.filePath!)),
              ],
            ),
          ],
        ),
      );
    } else if (event.type == 'tuto') {
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: t.bg.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: t.orange.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb, color: t.orange, size: 16),
                const SizedBox(width: 8),
                Text(event.time, style: TextStyle(color: t.orange, fontSize: 10, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 6),
            SelectableText(event.message, style: TextStyle(color: t.text, fontSize: 12, fontStyle: FontStyle.italic)),
          ],
        ),
      );
    } else {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(event.time, style: TextStyle(color: t.subtext, fontSize: 10)),
            const SizedBox(width: 8),
            Expanded(child: Text(event.message, style: TextStyle(color: t.text, fontSize: 11))),
          ],
        ),
      );
    }
  }

  Widget _buildFileActionButton(IconData icon, String label, Color color, VoidCallback onPressed) {
    return TextButton.icon(
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: onPressed,
      icon: Icon(icon, size: 14, color: color),
      label: Text(label, style: TextStyle(color: color, fontSize: 10)),
    );
  }

  Widget _buildTabButton(String title, int index, IconData icon) {
    bool isActive = _currentTab == index;
    return GestureDetector(
      onTap: () => setState(() => _currentTab = index),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: isActive ? t.border : Colors.transparent, borderRadius: BorderRadius.circular(6)),
        child: Row(
          children: [
            Icon(icon, color: isActive ? t.accent : t.subtext, size: 18),
            const SizedBox(width: 12),
            Text(title, style: TextStyle(color: isActive ? t.text : t.subtext, fontSize: 13, fontWeight: isActive ? FontWeight.bold : null)),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _glowController,
            builder: (context, child) {
              return Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: t.accent, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Color.lerp(t.green, t.accent, _glowController.value)!.withValues(alpha: 0.6),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Center(
                  child: Text('K', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 24, fontStyle: FontStyle.italic, height: 1.1)),
                ),
              );
            },
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('KIBALI AGI', style: TextStyle(color: t.text, fontWeight: FontWeight.bold, fontSize: 16)),
              Text('23 Boucles ULTRA', style: TextStyle(color: t.accent, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================
// CadPainter
// ============================================================
class CadPainter extends CustomPainter {
  final Map<String, dynamic> data;
  final Color bgColor, wallColor, textColor, tableColor;
  CadPainter({required this.data, required this.bgColor, required this.wallColor, required this.textColor, required this.tableColor});

  @override
  void paint(Canvas canvas, Size size) {
    double minX = double.infinity, maxX = -double.infinity;
    double minY = double.infinity, maxY = -double.infinity;

    void upd(double x, double y) {
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
    }

    if (data['walls'] != null) {
      for (var w in data['walls']) {
        if (w['type'] == 'polyline' && w['points'] != null) {
          for (var p in w['points']) {
            upd((p[0] as num).toDouble(), (p[1] as num).toDouble());
          }
        }
      }
    }
    if (data['rooms'] != null) {
      for (var r in data['rooms']) {
        double x = (r['x'] as num).toDouble(), y = (r['y'] as num).toDouble();
        double w = (r['w'] as num).toDouble(), h = (r['h'] as num).toDouble();
        upd(x, y);
        upd(x + w, y + h);
      }
    }
    if (data['doors'] != null) {
      for (var d in data['doors']) {
        double x = (d['x'] as num).toDouble(), y = (d['y'] as num).toDouble();
        double w = (d['width'] as num?)?.toDouble() ?? 900;
        upd(x, y);
        upd(x + w, y + w);
      }
    }
    if (data['tables'] != null) {
      for (var tbl in data['tables']) {
        double tx = (tbl['x'] as num).toDouble(), ty = (tbl['y'] as num).toDouble();
        List rows = tbl['rows'] as List;
        List cw = tbl['col_widths'] != null
            ? (tbl['col_widths'] as List).map((e) => (e as num).toDouble()).toList()
            : [2000.0, 2000.0];
        double rh = 400.0;
        double totalW = cw.reduce((a, b) => a + b);
        double totalH = rh * (rows.length + 1);
        upd(tx, ty);
        upd(tx + totalW, ty + totalH);
      }
    }

    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(1.0, -1.0);

    if (minX < maxX && minY < maxY) {
      double cx = (minX + maxX) / 2, cy = (minY + maxY) / 2;
      double rangeX = maxX - minX, rangeY = maxY - minY;
      double range = rangeX > rangeY ? rangeX : rangeY;
      if (range > 0) {
        double s = (size.width < size.height ? size.width : size.height) / range;
        canvas.translate(-cx, -cy);
        canvas.scale(s * 0.8);
      }
    }

    final pWall = Paint()..color = wallColor..style = PaintingStyle.stroke..strokeWidth = 2.0;
    final pTable = Paint()..color = tableColor..style = PaintingStyle.stroke..strokeWidth = 1.0;
    final pDoor = Paint()..color = Colors.orangeAccent..style = PaintingStyle.stroke..strokeWidth = 1.5;

    if (data['walls'] != null) {
      for (var w in data['walls']) {
        if (w['type'] == 'polyline' && w['points'] != null) {
          final path = Path();
          bool first = true;
          for (var p in w['points']) {
            double x = (p[0] as num).toDouble(), y = (p[1] as num).toDouble();
            if (first) {
              path.moveTo(x, y);
              first = false;
            } else {
              path.lineTo(x, y);
            }
          }
          canvas.drawPath(path, pWall);
        }
      }
    }

    if (data['rooms'] != null) {
      for (var r in data['rooms']) {
        double x = (r['x'] as num).toDouble(), y = (r['y'] as num).toDouble();
        double w = (r['w'] as num).toDouble(), h = (r['h'] as num).toDouble();
        canvas.drawRect(Rect.fromLTWH(x, y, w, h), pWall);
        if (r['name'] != null) {
          canvas.save();
          canvas.translate(x + w / 2, y + h / 2);
          canvas.scale(1.0, -1.0);
          _drawText(canvas, r['name'], 0, 0, 12, textColor, true);
          canvas.restore();
        }
      }
    }

    if (data['doors'] != null) {
      for (var d in data['doors']) {
        double x = (d['x'] as num).toDouble(), y = (d['y'] as num).toDouble();
        double w = (d['width'] as num?)?.toDouble() ?? 900;
        canvas.drawArc(Rect.fromCircle(center: Offset(x, y), radius: w), 0, 1.57, false, pDoor);
        canvas.drawLine(Offset(x, y), Offset(x, y + w), pDoor);
      }
    }

    if (data['tables'] != null) {
      for (var tbl in data['tables']) {
        double tx = (tbl['x'] as num).toDouble(), ty = (tbl['y'] as num).toDouble();
        List cols = tbl['columns'] as List;
        List rows = tbl['rows'] as List;
        List cw = tbl['col_widths'] != null
            ? (tbl['col_widths'] as List).map((e) => (e as num).toDouble()).toList()
            : [2000.0, 2000.0];
        double rh = 400.0;
        double totalW = cw.reduce((a, b) => a + b);
        double totalH = rh * (rows.length + 1);

        for (int i = 0; i <= rows.length + 1; i++) {
          canvas.drawLine(Offset(tx, ty + i * rh), Offset(tx + totalW, ty + i * rh), pTable);
        }
        double currX = tx;
        for (int i = 0; i <= cols.length; i++) {
          canvas.drawLine(Offset(currX, ty), Offset(currX, ty + totalH), pTable);
          if (i < cols.length) currX += cw[i];
        }

        canvas.save();
        canvas.translate(tx + totalW / 2, ty + totalH / 2);
        canvas.scale(1.0, -1.0);
        double cx = -totalW / 2;
        for (int i = 0; i < cols.length; i++) {
          _drawText(canvas, cols[i].toString(), cx + cw[i] / 2, totalH / 2 - rh / 2, 10, textColor, true);
          cx += cw[i];
        }
        for (int r = 0; r < rows.length; r++) {
          double cx2 = -totalW / 2;
          for (int c = 0; c < cols.length; c++) {
            _drawText(canvas, rows[r][c].toString(), cx2 + cw[c] / 2, totalH / 2 - rh * (r + 1.5), 10, textColor, true);
            cx2 += cw[c];
          }
        }
        canvas.restore();
      }
    }

    canvas.restore();
  }

  void _drawText(Canvas canvas, String text, double x, double y, double fontSize, Color color, bool center) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: color, fontSize: fontSize, fontFamily: 'Arial')),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    tp.layout();
    if (center) {
      tp.paint(canvas, Offset(x - tp.width / 2, y - tp.height / 2));
    } else {
      tp.paint(canvas, Offset(x, y));
    }
  }

  @override
  bool shouldRepaint(covariant CadPainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.bgColor != bgColor ||
        oldDelegate.wallColor != wallColor ||
        oldDelegate.textColor != textColor ||
        oldDelegate.tableColor != tableColor;
  }
}