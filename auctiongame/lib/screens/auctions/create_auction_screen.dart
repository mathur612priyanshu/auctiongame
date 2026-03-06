import 'dart:convert';

import 'package:auctiongame/api/auctionsservice.dart';
import 'package:auctiongame/providers/userprovider.dart';
import 'package:auctiongame/theme/appcolor.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

class CreateAuctionScreen extends StatefulWidget {
  static const routeName = '/create-auction';

  const CreateAuctionScreen({Key? key}) : super(key: key);

  @override
  _CreateAuctionScreenState createState() => _CreateAuctionScreenState();
}

class _CreateAuctionScreenState extends State<CreateAuctionScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _nameController = TextEditingController();
  final _typeController = TextEditingController();
  final _minPlayersController = TextEditingController();
  final _startTimeController = TextEditingController();
  final _runPointController = TextEditingController();
  final _wicketPointController = TextEditingController();
  final _captainPointController = TextEditingController();

  final _vicecaptainPointController = TextEditingController();

  final _maxPlayerAllowedController = TextEditingController();
  final _entryAmountController = TextEditingController();
  final _basePriceController = TextEditingController(text: '0');
  final _countedPlayersController = TextEditingController(text: '0');

  bool _isLoading = false;
  DateTime? _selectedDate;

  // NEW STATE
  String? _selectedCategory;
  List<dynamic> _playerGroups = [];
  List<String> _selectedGroups = [];
  List<Map<String, dynamic>> _selectedPlayers = [];

  @override
  void dispose() {
    _nameController.dispose();
    _typeController.dispose();
    _minPlayersController.dispose();
    _startTimeController.dispose();
    _runPointController.dispose();
    _wicketPointController.dispose();
    _maxPlayerAllowedController.dispose();
    _entryAmountController.dispose();
    _basePriceController.dispose();
    _countedPlayersController.dispose();
    super.dispose();
  }

  Future<void> _selectDateTime(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );

    if (date != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (time != null) {
        setState(() {
          _selectedDate = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
          _startTimeController.text = DateFormat(
            'yyyy-MM-dd HH:mm',
          ).format(_selectedDate!);
        });
      }
    }
  }

  /// Fetch groups based on category
  Future<void> _fetchPlayerGroups(String category) async {
    try {
      final res = await AuctionService.getGroupsByCategory(category);
      print(res.body);

      final jsonResponse = json.decode(res.body);
      print(jsonResponse);

      if (jsonResponse['success'] == true) {
        setState(() {
          _playerGroups = jsonResponse['data'];
        });
      }
    } catch (e) {
      debugPrint("Error fetching groups: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to fetch player groups")),
      );
    }
  }

  /// Handle group selection toggle
  Future<void> _handleGroupSelection(String groupName, bool isSelected) async {
    try {
      if (isSelected) {
        // Add group
        setState(() {
          _selectedGroups.add(groupName);
        });

        // Fetch players in this group
        final res = await AuctionService.getPlayersByGroup(groupName);
        final jsonResponse = json.decode(res.body);

        if (jsonResponse['success'] == true) {
          final groupPlayers = List<Map<String, dynamic>>.from(
            jsonResponse['data'],
          );
          setState(() {
            // Add only new players
            final existingIds = _selectedPlayers.map((p) => p['id']).toSet();
            final newPlayers = groupPlayers.where(
              (p) => !existingIds.contains(p['id']),
            );
            _selectedPlayers.addAll(newPlayers);
          });
        }
      } else {
        // Remove group
        setState(() {
          _selectedGroups.remove(groupName);
          _selectedPlayers.removeWhere((p) => p['playerGroup'] == groupName);
        });
      }
    } catch (e) {
      debugPrint("Error handling group selection: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to handle group selection")),
      );
    }
  }

  Future<void> _createAuction() async {
    if (!_formKey.currentState!.validate()) return;

    if (int.tryParse(_minPlayersController.text) != null &&
        int.parse(_minPlayersController.text) < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Minimum players cannot be less than 3')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<UserProvider>(context, listen: false);
      final userId = authProvider.user?.id;
      if (userId == null) throw Exception('User not authenticated');

      // Extract player IDs
      final selectedPlayerIds =
          _selectedPlayers.map((p) => int.parse(p['id'].toString())).toList();

      final auctionData = {
        'name': _nameController.text.trim(),
        'category': _selectedCategory,
        'minPlayers': int.tryParse(_minPlayersController.text),
        'startTime': _selectedDate?.toIso8601String(),
        'runPoint': int.tryParse(_runPointController.text) ?? 1,
        'wicketPoint': int.tryParse(_wicketPointController.text) ?? 10,
        'captain': int.tryParse(_captainPointController.text) ?? 2,
        'vicecaptain': int.tryParse(_vicecaptainPointController.text) ?? 1,
        'maxPlayerAllowed': int.tryParse(_maxPlayerAllowedController.text),
        'entryAmount': int.tryParse(_entryAmountController.text),
        'basePrice': int.tryParse(_basePriceController.text) ?? 0,
        'countedPlayers': int.tryParse(_countedPlayersController.text) ?? 0,
        'createdBy': userId.toString(),
        'selectedGroups': _selectedGroups,
        'selectedPlayers': selectedPlayerIds,
      };

      debugPrint("Creating auction with data: $auctionData");

      final response = await AuctionService.createAuction(data: auctionData);

      if (response['success'] == true) {
        if (!mounted) return;
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Auction created successfully')),
        );
      } else {
        throw Exception(response['message'] ?? 'Failed to create auction');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.accentColor,
              AppColors.secondaryaccentColor,
              AppColors.primaryColor,
            ],
          ),
        ),
        child: Form(
          key: _formKey,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 20),
                        Text(
                          "Create Auction",
                          style: Theme.of(
                            context,
                          ).textTheme.headlineLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),

                        // Auction Name
                        CustomTextField(
                          controller: _nameController,
                          label: 'Auction Name',
                          validator:
                              (v) =>
                                  v == null || v.isEmpty
                                      ? 'Please enter a name'
                                      : null,
                        ),
                        const SizedBox(height: 16),

                        // Category
                        DropdownButtonFormField<String>(
                          dropdownColor: AppColors.secondaryaccentColor,
                          style: const TextStyle(color: Colors.white),
                          value: _selectedCategory,
                          items: const [
                            DropdownMenuItem(
                              value: "cricket",
                              child: Text(
                                "Cricket",
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                            DropdownMenuItem(
                              value: "football",
                              child: Text(
                                "Football",
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedCategory = value;
                              _playerGroups = [];
                              _selectedGroups = [];
                              _selectedPlayers = [];
                            });
                            if (value != null) _fetchPlayerGroups(value);
                          },
                          decoration: InputDecoration(
                            labelText: "Category",
                            labelStyle: const TextStyle(color: Colors.white),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          validator:
                              (v) =>
                                  v == null || v.isEmpty
                                      ? "Please select a category"
                                      : null,
                        ),
                        const SizedBox(height: 16),

                        // Groups
                        if (_playerGroups.isNotEmpty) ...[
                          Text(
                            "Select Groups",
                            style: TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ..._playerGroups.map((g) {
                            final groupName = g['groupName'] ?? g.toString();
                            return CheckboxListTile(
                              title: Text(
                                groupName,
                                style: const TextStyle(color: Colors.white),
                              ),
                              value: _selectedGroups.contains(groupName),
                              activeColor: Colors.white,
                              checkColor: Colors.black,
                              onChanged:
                                  (val) => _handleGroupSelection(
                                    groupName,
                                    val ?? false,
                                  ),
                            );
                          }),
                          const SizedBox(height: 16),
                        ],

                        CustomTextField(
                          controller: _minPlayersController,
                          label: 'Number of participants *',
                          keyboardType: TextInputType.number,
                          validator:
                              (v) =>
                                  v == null || v.isEmpty
                                      ? 'Enter minimum players'
                                      : null,
                        ),
                        const SizedBox(height: 16),
                        CustomTextField(
                          controller: _countedPlayersController,
                          label: 'Player Counted for auction',
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 16),

                        // Start time picker
                        TextFormField(
                          controller: _startTimeController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText:
                                'Start Time (time should be atleast 5 min ahead of current time)',
                            labelStyle: const TextStyle(color: Colors.white),
                            suffixIcon: IconButton(
                              icon: const Icon(
                                Icons.calendar_today,
                                color: Colors.white,
                              ),
                              onPressed: () => _selectDateTime(context),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          readOnly: true,
                          validator:
                              (v) =>
                                  v == null || v.isEmpty
                                      ? 'Select start time'
                                      : null,
                        ),
                        const SizedBox(height: 16),

                        CustomTextField(
                          controller: _runPointController,
                          label: 'Run Point',
                          keyboardType: TextInputType.number,
                          validator:
                              (v) =>
                                  v == null || v.isEmpty
                                      ? 'Enter number of counted players'
                                      : null,
                        ),

                        const SizedBox(height: 16),

                        CustomTextField(
                          controller: _wicketPointController,
                          label: 'Wicket Point',
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 16),

                        CustomTextField(
                          controller: _captainPointController,
                          label: 'Captain Points',
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 16),

                        CustomTextField(
                          controller: _vicecaptainPointController,
                          label: 'Vice Captain Point',
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 16),

                        // CustomTextField(
                        //   controller: _maxPlayerAllowedController,
                        //   label: 'Max Players Allowed (Optional)',
                        //   keyboardType: TextInputType.number,
                        // ),
                        // const SizedBox(height: 16),

                        // CustomTextField(
                        //   controller: _entryAmountController,
                        //   label: 'Entry Amount (Optional)',
                        //   keyboardType: TextInputType.number,
                        // ),
                        // const Spacer(),
                        const SizedBox(height: 24),
                        CustomButton(
                          onPressed: _isLoading ? null : _createAuction,
                          backgroundColor: AppColors.secondaryaccentColor,
                          child:
                              _isLoading
                                  ? const CircularProgressIndicator(
                                    color: Colors.white,
                                  )
                                  : const Text(
                                    "Create Auction",
                                    style: TextStyle(color: Colors.white),
                                  ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final bool obscureText;
  final int maxLines;

  const CustomTextField({
    Key? key,
    required this.controller,
    required this.label,
    this.validator,
    this.keyboardType,
    this.obscureText = false,
    this.maxLines = 1,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      obscureText: obscureText,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white),
        hintStyle: const TextStyle(color: Colors.white54),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
      ),
    );
  }
}

class CustomButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final Color backgroundColor;

  const CustomButton({
    Key? key,
    required this.onPressed,
    required this.child,
    this.backgroundColor = Colors.blue,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 3,
        ),
        child: child,
      ),
    );
  }
}
