import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';

void main() {
  runApp(const KibaliTerminalApp());
}

class KibaliTheme {
  final String name;
  final Color bg;
  final Color panel;
  final Color border;
  final Color text;
  final Color subtext;
  final Color accent;
  final Color green;
  final Color orange;

  KibaliTheme({
    required this.name, required this.bg, required this.panel, required this.border,
    required this.text, required this.subtext, required this.accent, required this.green, required this.orange,
  });
}

final List<KibaliTheme> themes = [
  KibaliTheme(
    name: 'Tokyo Night', bg: const Color(0xFF1a1b26), panel: const Color(0xFF16161e),
    border: const Color(0xFF292e42), text: const Color(0xFFa9b1d6), subtext: const Color(0xFF565f89),
    accent: const Color(0xFF7aa2f7), green: const Color(0xFF9ece6a), orange: const Color(0xFFe0af68),
  ),
  KibaliTheme(
    name: 'Cyberpunk', bg: const Color(0xFF0d0221), panel: const Color(0xFF190f2e),
    border: const Color(0xFF7209b7), text: const Color(0xFFf72585), subtext: const Color(0xFF9d4edd),
    accent: const Color(0xFF00f5d4), green: const Color(0xFF00f5d4), orange: const Color(0xFFFF9E00),
  ),
  KibaliTheme(
    name: 'Jesus!', bg: const Color(0xFF282a36), panel: const Color(0xFF44475a),
    border: const Color(0xFF6272a4), text: const Color(0xFFf8f8f2), subtext: const Color(0xFF6272a4),
    accent: const Color(0xFFbd93f9), green: const Color(0xFF50fa7b), orange: const Color(0xFFffb86c),
  ),
  KibaliTheme(
    name: 'Blanche', bg: const Color(0xFFF8FAFC), panel: const Color(0xFFF1F5F9),
    border: const Color(0xFFCBD5E1), text: const Color(0xFF0F172A), subtext: const Color(0xFF64748B),
    accent: const Color(0xFF3B82F6), green: const Color(0xFF10B981), orange: const Color(0xFFF59E0B),
  ),
  KibaliTheme(
    name: 'Noir', bg: const Color(0xFF000000), panel: const Color(0xFF111111),
    border: const Color(0xFF222222), text: const Color(0xFFFFFFFF), subtext: const Color(0xFF888888),
    accent: const Color(0xFF00E5FF), green: const Color(0xFF00FF00), orange: const Color(0xFFFFAA00),
  ),
  KibaliTheme(
    name: 'Blue', bg: const Color(0xFF0B132B), panel: const Color(0xFF071024),
    border: const Color(0xFF1C2541), text: const Color(0xFFE0E1DD), subtext: const Color(0xFF778DA9),
    accent: const Color(0xFF00B4D8), green: const Color(0xFF06D6A0), orange: const Color(0xFFFFD166),
  ),
];

class LiveEvent {
  final String time;
  final String message;
  final String type;
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
      theme: ThemeData(brightness: Brightness.dark, scaffoldBackgroundColor: theme.bg, fontFamily: GoogleFonts.inter().fontFamily),
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
  final ScrollController _terminalScrollController = ScrollController();
  final ScrollController _liveScrollController = ScrollController();
  
  final String _baseDir = 'D:\\CPT_Analysis_Studio_PORTABLE';
  
  String _terminalBuffer = 'KIBALI AGI Terminal - Prêt.\nPosez votre question ou tapez une commande.\n\n';
  
  bool _isEngineRunning = false;
  bool _isAiThinking = false;
  int _currentTab = 0;

  List<LiveEvent> _liveEvents = [
    LiveEvent(time: 'INFO', message: 'Bus live initialisé. En attente d\'événements...')
  ];

  double _ceppPrice = 85.0;
  double _ceppProduction = 6000000.0;
  double _ceppCosts = 2500000.0;
  double _ceppRmpRate = 12.5;
  double _ceppCostOilCap = 70.0;

  Process? _engineProcess;
  late AnimationController _glowController;
  
  // Timer pour le défilement automatique des tutos
  Timer? _autoTourTimer;
  int _currentToolIndex = 0;

  List<String> _allTools = [];
  List<String> _filteredTools = [];
  Map<String, String> _toolDescriptions = {};
  bool _isLoadingTools = true;

  KibaliTheme get t => widget.theme;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);
    _fetchRagTools();
    _searchController.addListener(_filterTools);
  }

  @override
  void dispose() {
    _autoTourTimer?.cancel(); // On arrête le timer proprement
    _glowController.dispose();
    _engineProcess?.kill();
    _inputController.dispose();
    _searchController.dispose();
    super.dispose();
  }

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
          String desc = tool['function']['description'] ?? "Aucune description fournie.";
          tempNames.add(name);
          tempDescs[name] = desc;
        }

        setState(() {
          _allTools = tempNames;
          _filteredTools = List.from(_allTools);
          _toolDescriptions = tempDescs;
          _isLoadingTools = false;
        });
        
        _addLiveEvent('RAG connecté : ${_allTools.length} outils chargés avec succès.', 'info');
        
        // LANCEMENT DU DEFILEMENT AUTOMATIQUE UNE FOIS LES OUTILS CHARGES
        _startAutoTour();
        
      } else { _loadFallbackTools(); }
    } catch (e) { _loadFallbackTools(); }
  }

  void _loadFallbackTools() {
    setState(() {
      _allTools = ['generate_pdf', 'calculate'];
      _filteredTools = List.from(_allTools);
      _toolDescriptions = {
        'generate_pdf': 'Génère un rapport PDF.',
        'calculate': 'Effectue un calcul mathématique.'
      };
      _isLoadingTools = false;
    });
    _addLiveEvent('RAG hors ligne. Mode dégradé activé.', 'info');
    _startAutoTour();
  }

  // La fonction qui fait défiler les tutos tout seul
  void _startAutoTour() {
    _autoTourTimer?.cancel();
    _autoTourTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_allTools.isEmpty) return;
      
      // Pioche l'outil actuel et passe au suivant
      String toolName = _allTools[_currentToolIndex];
      String desc = _toolDescriptions[toolName] ?? "Description indisponible.";
      
      _addLiveEvent('[AUTO-TOUR] $toolName :\n$desc', 'tuto');
      
      // Boucle à l'infini
      _currentToolIndex = (_currentToolIndex + 1) % _allTools.length;
    });
  }

  void _filterTools() {
    final query = _searchController.text.toLowerCase();
    setState(() => _filteredTools = _allTools.where((tool) => tool.toLowerCase().contains(query)).toList());
  }

  void _addLiveEvent(String message, String type, {String? filePath}) {
    if (!mounted) return;
    setState(() {
      _liveEvents.add(LiveEvent(time: TimeOfDay.now().format(context), message: message, type: type, filePath: filePath));
    });
    _scrollLiveToBottom();
  }

  void _scrollLiveToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_liveScrollController.hasClients) {
        _liveScrollController.animateTo(
          _liveScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _startEngine() async {
    if (_engineProcess != null) _engineProcess!.kill();
    
    setState(() {
      _isEngineRunning = true;
      _terminalBuffer += '\n[SYSTEM] Démarrage du moteur KIBALI 21 boucles...\n';
    });
    _addLiveEvent('Démarrage du moteur 21 boucles...', 'info');

    final pythonPath = 'D:\\CPT_Analysis_Studio_PORTABLE\\environment\\python.exe';
    final scriptPath = 'D:\\CPT_Analysis_Studio_PORTABLE\\KIBALI_MOTEUR_V3_FAST.py';

    _engineProcess = await Process.start(pythonPath, [scriptPath], workingDirectory: _baseDir);

    String cleanAnsi(String input) => input.replaceAll(RegExp(r'\x1B\[[0-9;]*[mGKH]'), '');

    _engineProcess!.stdout.transform(utf8.decoder).listen((data) {
      String cleanData = cleanAnsi(data).replaceAll('\r\n', '\n').replaceAll('\r', '\n');
      setState(() { _terminalBuffer += cleanData; });
      _scrollToBottom();
      
      if (cleanData.contains('🔄 CYCLE')) {
        _addLiveEvent('Moteur : Nouveau cycle d\'analyse...', 'info');
      }
      
      final fileRegex = RegExp(r'([a-zA-Z0-9_\-]+\.(pdf|xlsx|docx|csv|txt|json))');
      final matches = fileRegex.allMatches(cleanData);
      for (var match in matches) {
        String fileName = match.group(1)!;
        String fullPath = '$_baseDir\\$fileName';
        
        if (!_liveEvents.any((e) => e.filePath == fullPath)) {
          _addLiveEvent('Fichier généré : $fileName', 'file', filePath: fullPath);
        }
      }

      if (cleanData.contains('👤 Vous > ') || cleanData.contains('[MISSION ACCOMPLIE')) {
        setState(() => _isAiThinking = false);
      }
    });

    _engineProcess!.stderr.transform(utf8.decoder).listen((data) {
      setState(() => _terminalBuffer += '[ERREUR] ${cleanAnsi(data)}\n');
      _scrollToBottom();
    });
  }

  void _sendCommand() {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _terminalBuffer += '\n👤 Vous > $text\n';
      _inputController.clear();
      _currentTab = 0; 
      _isAiThinking = true;
    });
    _scrollToBottom();

    if (_engineProcess == null) {
      _startEngine();
      Future.delayed(const Duration(seconds: 2), () {
        _engineProcess?.stdin.writeln(text);
      });
    } else {
      _engineProcess!.stdin.writeln(text);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_terminalScrollController.hasClients) {
        _terminalScrollController.animateTo(
          _terminalScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _openFile(String path) async {
    try { 
      if (!File(path).existsSync()) {
        _addLiveEvent('ERREUR : Fichier introuvable à $path', 'info');
        return;
      }
      await Process.run('cmd', ['/c', 'start', '', path]); 
    } catch (e) { debugPrint("Erreur ouverture: $e"); }
  }

  void _openFolder(String path) async {
    try { await Process.run('explorer.exe', ['/select,', path]); } catch (e) { debugPrint("Erreur dossier: $e"); }
  }

  void _downloadFile(String path) async {
    try {
      String fileName = path.split('\\').last;
      String psScript = '''
        Add-Type -AssemblyName System.Windows.Forms
        \$SaveFileDialog = New-Object System.Windows.Forms.SaveFileDialog
        \$SaveFileDialog.FileName = "$fileName"
        \$SaveFileDialog.Filter = "Tous les fichiers (*.*)|*.*"
        if (\$SaveFileDialog.ShowDialog() -eq "OK") {
            Copy-Item -Path "$path" -Destination \$SaveFileDialog.FileName -Force
        }
      ''';
      await Process.run('powershell', ['-Command', psScript]);
    } catch (e) { debugPrint("Erreur telechargement: $e"); }
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
                  padding: const EdgeInsets.all(12.0),
                  child: TextField(
                    controller: _searchController,
                    style: TextStyle(color: t.text, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Rechercher un outil...', hintStyle: TextStyle(color: t.subtext),
                      prefixIcon: Icon(Icons.search, color: t.subtext, size: 18),
                      filled: true, fillColor: t.bg,
                      border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.circular(6)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                              title: Text(_filteredTools[index], style: TextStyle(color: t.text, fontSize: 13, fontFamily: 'monospace'), overflow: TextOverflow.ellipsis),
                              hoverColor: t.border,
                              onTap: () {
                                String toolName = _filteredTools[index];
                                String desc = _toolDescriptions[toolName] ?? "Aucune description disponible.";
                                _addLiveEvent('[MANUEL] $toolName :\n$desc', 'tuto');
                                _inputController.text = toolName;
                              },
                            );
                          },
                        ),
                      ),
                ),
                Container(
                  width: double.infinity, padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(border: Border(top: BorderSide(color: t.border))),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('KIBALI AGI v10 (21 Boucles)', style: TextStyle(color: t.accent, fontSize: 11, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('Dev IA : Nyundu Fancis Arnaud', style: TextStyle(color: t.subtext, fontSize: 10)),
                    ],
                  ),
                )
              ],
            ),
          ),

          Expanded(
            child: Container(
              decoration: BoxDecoration(color: t.bg),
              child: Column(
                children: [
                  Container(
                    height: 50,
                    decoration: BoxDecoration(color: t.panel, border: Border(bottom: BorderSide(color: t.border))),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        _buildTab('Terminal Agent', 0),
                        _buildTab('Plugin CEPP', 1),
                        const Spacer(),
                        PopupMenuButton<int>(
                          icon: Icon(Icons.palette, color: t.accent, size: 20),
                          onSelected: widget.onChangeTheme,
                          itemBuilder: (context) => List.generate(themes.length, (index) => PopupMenuItem(
                            value: index,
                            child: Row(children: [
                              Container(width: 16, height: 16, decoration: BoxDecoration(color: themes[index].accent, shape: BoxShape.circle)),
                              const SizedBox(width: 10),
                              Text(themes[index].name, style: TextStyle(color: t.text, fontSize: 12)),
                            ]),
                          )),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _currentTab == 0 ? _buildTerminalView() : _buildCeppPlugin(),
                  ),
                  if (_currentTab == 0)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: t.panel, border: Border(top: BorderSide(color: t.border))),
                      child: Row(
                        children: [
                          Text('D:\\CPT_Analysis_Studio_PORTABLE > ', style: GoogleFonts.robotoMono(color: t.green, fontSize: 13)),
                          Expanded(
                            child: TextField(
                              controller: _inputController,
                              style: GoogleFonts.robotoMono(color: t.text, fontSize: 14),
                              decoration: InputDecoration(border: InputBorder.none, hintText: 'Entrez votre commande ou question...', hintStyle: TextStyle(color: t.subtext)),
                              onSubmitted: (_) => _sendCommand(),
                            ),
                          ),
                          if (_isAiThinking)
                            const Padding(
                              padding: EdgeInsets.only(right: 15),
                              child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange)),
                            ),
                          IconButton(icon: Icon(Icons.send, color: t.accent), onPressed: _sendCommand)
                        ],
                      ),
                    )
                ],
              ),
            ),
          ),

          Container(
            width: 320,
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
                    itemBuilder: (context, index) {
                      final event = _liveEvents[index];
                      return _buildLiveItem(event);
                    },
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildLiveItem(LiveEvent event) {
    if (event.type == 'file') {
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: t.bg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: t.accent),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.insert_drive_file, color: t.accent, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(event.message, style: TextStyle(color: t.text, fontSize: 12, fontWeight: FontWeight.bold))),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton.icon(
                  onPressed: () => _openFile(event.filePath!),
                  icon: Icon(Icons.open_in_new, size: 14, color: t.green),
                  label: Text('Ouvrir', style: TextStyle(color: t.green, fontSize: 11)),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(60, 24)),
                ),
                TextButton.icon(
                  onPressed: () => _openFolder(event.filePath!),
                  icon: Icon(Icons.folder_open, size: 14, color: t.orange),
                  label: Text('Dossier', style: TextStyle(color: t.orange, fontSize: 11)),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(60, 24)),
                ),
                TextButton.icon(
                  onPressed: () => _downloadFile(event.filePath!),
                  icon: Icon(Icons.download, size: 14, color: t.accent),
                  label: Text('Télécharger', style: TextStyle(color: t.accent, fontSize: 11)),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(60, 24)),
                ),
              ],
            )
          ],
        ),
      );
    } else if (event.type == 'tuto') {
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: t.bg.withOpacity(0.5),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: t.orange.withOpacity(0.5)),
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
            SelectableText(event.message, style: TextStyle(color: t.text, fontSize: 12, fontStyle: FontStyle.italic, height: 1.4)),
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

  Widget _buildTerminalView() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        controller: _terminalScrollController,
        child: SelectableText(
          _terminalBuffer,
          style: GoogleFonts.robotoMono(color: t.text, fontSize: 13, height: 1.5),
        ),
      ),
    );
  }

  Widget _buildCeppPlugin() {
    double grossRevenue = _ceppPrice * _ceppProduction;
    double rmpAmount = grossRevenue * (_ceppRmpRate / 100);
    double netRevenue = grossRevenue - rmpAmount;
    double maxCostOil = netRevenue * (_ceppCostOilCap / 100);
    double costOilRecovered = _ceppCosts < maxCostOil ? _ceppCosts : maxCostOil;
    double profitOil = netRevenue - costOilRecovered;
    
    double stateSharePct = 0.45;
    double contractorSharePct = 0.55;
    
    if (_ceppProduction > 20000 && _ceppProduction <= 50000) {
      stateSharePct = 0.50;
      contractorSharePct = 0.50;
    } else if (_ceppProduction > 50000) {
      stateSharePct = 0.60;
      contractorSharePct = 0.40;
    }
    
    double stateProfitOil = profitOil * stateSharePct;
    double contractorProfitOil = profitOil * contractorSharePct;
    double totalStateRevenue = rmpAmount + stateProfitOil;
    double totalContractorRevenue = costOilRecovered + contractorProfitOil;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('TBFISCAL KIBALI V3 - Calculateur CEPP', style: TextStyle(color: t.accent, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Moteur de calcul des droits à l\'huile de l\'État (Temps Réel)', style: TextStyle(color: t.subtext, fontSize: 14)),
          const Divider(height: 40, color: Color(0xFF292e42)),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 4,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: t.panel, borderRadius: BorderRadius.circular(12), border: Border.all(color: t.border)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('PARAMÈTRES DU CONTRAT', style: TextStyle(color: t.accent, fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 20),
                      _buildSlider('Prix du Baril (USD)', _ceppPrice, 50, 150, (v) => setState(() => _ceppPrice = v), suffix: '\$'),
                      _buildSlider('Production Totale (Barils/j)', _ceppProduction, 1000000, 10000000, (v) => setState(() => _ceppProduction = v), isInt: true),
                      _buildSlider('Coûts Pétroliers (USD)', _ceppCosts, 0, 5000000, (v) => setState(() => _ceppCosts = v), suffix: '\$'),
                      _buildSlider('Taux de Redevance RMP (%)', _ceppRmpRate, 0, 20, (v) => setState(() => _ceppRmpRate = v)),
                      _buildSlider('Plafond Cost Oil (%)', _ceppCostOilCap, 0, 100, (v) => setState(() => _ceppCostOilCap = v)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                flex: 5,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: _buildResultCard('DROITS À L\'HUILE (ÉTAT)', totalStateRevenue, t.orange)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildResultCard('REDEVANCE (RMP)', rmpAmount, t.orange)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _buildResultCard('COST OIL (RÉCUPÉRÉ)', costOilRecovered, t.accent)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildResultCard('PROFIT OIL TOTAL', profitOil, t.green)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 200,
                      child: PieChart(
                        PieChartData(
                          sectionsSpace: 4,
                          centerSpaceRadius: 50,
                          sections: [
                            PieChartSectionData(color: t.orange, value: rmpAmount, title: 'RMP', radius: 30, titleStyle: TextStyle(color: t.bg, fontWeight: FontWeight.bold, fontSize: 10)),
                            PieChartSectionData(color: t.accent, value: costOilRecovered, title: 'Cost', radius: 30, titleStyle: TextStyle(color: t.bg, fontWeight: FontWeight.bold, fontSize: 10)),
                            PieChartSectionData(color: t.green, value: stateProfitOil, title: 'État', radius: 30, titleStyle: TextStyle(color: t.bg, fontWeight: FontWeight.bold, fontSize: 10)),
                            PieChartSectionData(color: t.text.withOpacity(0.5), value: contractorProfitOil, title: 'Contracteur', radius: 30, titleStyle: TextStyle(color: t.bg, fontWeight: FontWeight.bold, fontSize: 10)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: t.panel, borderRadius: BorderRadius.circular(8), border: Border.all(color: t.border)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('DÉTAIL DU PARTAGE DE LA PRODUCTION', style: TextStyle(color: t.accent, fontSize: 12, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          _buildDetailRow('Profit Oil État (${(stateSharePct*100).toStringAsFixed(0)}%)', stateProfitOil, t.orange),
                          _buildDetailRow('Profit Oil Contracteur (${(contractorSharePct*100).toStringAsFixed(0)}%)', contractorProfitOil, t.green),
                          const Divider(color: Color(0xFF292e42), height: 20),
                          _buildDetailRow('TOTAL REVENUS ÉTAT', totalStateRevenue, t.orange, isBold: true),
                          _buildDetailRow('TOTAL REVENUS CONTRACTEUR', totalContractorRevenue, t.green, isBold: true),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, double value, Color color, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: t.text, fontSize: 12, fontWeight: isBold ? FontWeight.bold : null)),
          Text('${value.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]} ')} \$', 
              style: TextStyle(color: color, fontSize: 12, fontWeight: isBold ? FontWeight.bold : null)),
        ],
      ),
    );
  }

  Widget _buildSlider(String label, double value, double min, double max, Function(double) onChanged, {String suffix = '', bool isInt = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(color: t.text, fontSize: 13)),
            Text('${isInt ? value.toInt() : value.toStringAsFixed(1)} $suffix', style: TextStyle(color: t.accent, fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
        Slider(value: value, min: min, max: max, activeColor: t.accent, inactiveColor: t.border, onChanged: onChanged),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _buildResultCard(String title, double value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: t.panel, borderRadius: BorderRadius.circular(8), border: Border.all(color: t.border)),
      child: Column(
        children: [
          Text(title, style: TextStyle(color: t.subtext, fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('${value.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]} ')} \$', style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildTab(String title, int index) {
    bool isActive = _currentTab == index;
    return GestureDetector(
      onTap: () => setState(() => _currentTab = index),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(color: isActive ? t.bg : Colors.transparent, borderRadius: BorderRadius.circular(4)),
        child: Text(title, style: TextStyle(color: isActive ? t.accent : t.subtext, fontSize: 12, fontWeight: isActive ? FontWeight.bold : null)),
      ),
    );
  }

  Widget _buildLogoHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.border))),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _glowController,
            builder: (context, child) {
              return Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: t.accent, width: 2),
                  boxShadow: [BoxShadow(color: Color.lerp(t.green, t.accent, _glowController.value)!.withOpacity(0.6), blurRadius: 12, spreadRadius: 2)],
                ),
                child: Center(child: Text('K', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 24, fontStyle: FontStyle.italic, height: 1.1))),
              );
            },
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('KIBALI AGI', style: TextStyle(color: t.text, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.2)),
              const SizedBox(height: 2),
              Text('21 Boucles', style: TextStyle(color: t.accent, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}