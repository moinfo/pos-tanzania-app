import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/clients_config.dart';
import '../models/client_config.dart';
import '../services/api_service.dart';
import '../widgets/glassmorphic_card.dart';
import 'login_screen.dart';

class ClientSelectorScreen extends StatefulWidget {
  const ClientSelectorScreen({super.key});

  @override
  State<ClientSelectorScreen> createState() => _ClientSelectorScreenState();
}

class _ClientSelectorScreenState extends State<ClientSelectorScreen> {
  String? _selectedClientId;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadCurrentClient();
  }

  Future<void> _loadCurrentClient() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedClientId = prefs.getString('selected_client_id');
    });
  }

  Future<void> _selectClient(ClientConfig client) async {
    await ApiService.setCurrentClient(client.id);

    setState(() {
      _selectedClientId = client.id;
    });

    if (!mounted) return;

    // Navigate to login screen
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => const LoginScreen(),
      ),
    );
  }

  List<ClientConfig> get _filteredClients {
    if (_searchQuery.isEmpty) {
      return ClientsConfig.availableClients;
    }
    return ClientsConfig.availableClients.where((client) {
      return client.displayName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
             client.name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue.shade800,
              Colors.purple.shade600,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    Icon(
                      Icons.store,
                      size: 64,
                      color: Colors.white.withOpacity(0.9),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Select Client',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Choose which client to connect to',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),

              // Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: GlassmorphicCard(
                  child: TextField(
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search clients...',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                      prefixIcon: Icon(
                        Icons.search,
                        color: Colors.white.withOpacity(0.7),
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Client List
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  itemCount: _filteredClients.length,
                  itemBuilder: (context, index) {
                    final client = _filteredClients[index];
                    final isSelected = client.id == _selectedClientId;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: GlassmorphicCard(
                        borderRadius: 16,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          leading: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.green.withOpacity(0.3)
                                  : Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? Colors.green
                                    : Colors.white.withOpacity(0.3),
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              isSelected ? Icons.check_circle : Icons.store,
                              color: isSelected ? Colors.green : Colors.white70,
                            ),
                          ),
                          title: Text(
                            client.displayName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            client.name,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 12,
                            ),
                          ),
                          trailing: Icon(
                            Icons.arrow_forward_ios,
                            color: Colors.white.withOpacity(0.5),
                            size: 16,
                          ),
                          onTap: () => _selectClient(client),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
