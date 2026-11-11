import 'dart:async';

import 'package:carservice_customer/app/theme/app_theme.dart';
import 'package:carservice_customer/core/errors/app_failure.dart';
import 'package:carservice_customer/core/widgets/cs_ui.dart';
import 'package:carservice_customer/features/vehicles/domain/vehicle.dart';
import 'package:carservice_customer/features/vehicles/domain/vehicle_lookup_result.dart';
import 'package:carservice_customer/features/vehicles/domain/vehicle_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

final _platePattern = RegExp(r'^\d{4}[А-ЯЁӨҮ]{3}$');

class AddVehicleScreen extends StatefulWidget {
  const AddVehicleScreen({
    required this.repository,
    required this.onBack,
    required this.onAdded,
    super.key,
  });

  final VehicleRepository repository;
  final VoidCallback onBack;
  final ValueChanged<Vehicle> onAdded;

  @override
  State<AddVehicleScreen> createState() => _AddVehicleScreenState();
}

class _AddVehicleScreenState extends State<AddVehicleScreen> {
  final _plateController = TextEditingController();
  final _makeController = TextEditingController();
  final _modelController = TextEditingController();
  final _yearController = TextEditingController();
  final _vinController = TextEditingController();
  String? _fuelType;
  String? _wheelPosition;
  String? _colorName;
  int? _capacity;
  String? _purpose;
  Timer? _lookupTimer;
  String? _lastLookedUpPlate;

  bool _lookingUp = false;
  bool _isPlateValid = false;
  bool _submitting = false;
  String? _lookupMessage;
  String? _error;

  @override
  void dispose() {
    _lookupTimer?.cancel();
    _plateController.dispose();
    _makeController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _vinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = CarserviceTheme.of(context);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: CsCircleButton.back(context, onPressed: widget.onBack),
            ),
            const SizedBox(height: 20),
            Text(
              'Машин нэмэх',
              style: TextStyle(
                fontSize: 28,
                height: 34 / 28,
                fontWeight: FontWeight.w700,
                letterSpacing: 28 * -0.02,
                color: theme.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Машинаа нэмбэл захиалга хийхэд мэдээлэл автоматаар бөглөгдөнө.',
              style: TextStyle(fontSize: 15, height: 22 / 15, color: theme.mutedText),
            ),
            const SizedBox(height: 18),
            CsCard(
              radius: 18,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      CsIconTile(icon: Icons.directions_car_outlined),
                      SizedBox(width: 10),
                      Text(
                        'Миний машин',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _Labeled(
                    label: 'Улсын дугаар',
                    child: _PlateField(
                      child: TextField(
                        key: const ValueKey('vehicle-plate'),
                        controller: _plateController,
                        textCapitalization: TextCapitalization.characters,
                        textAlign: TextAlign.center,
                        maxLength: 7,
                        inputFormatters: const [_MongolianPlateInputFormatter()],
                        onChanged: _scheduleLookup,
                        cursorColor: theme.ink,
                        style: csMono(
                          fontSize: 26,
                          letterSpacing: 26 * 0.08,
                          color: theme.ink,
                        ),
                        decoration: InputDecoration(
                          isCollapsed: true,
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          counterText: '',
                          hintText: '1234УБА',
                          hintStyle: csMono(
                            fontSize: 26,
                            letterSpacing: 26 * 0.08,
                            color: theme.mutedText.withValues(alpha: 0.45),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _lookingUp ? 'ХУР-аас хайж байна…' : '4 цифр + 3 кирилл үсэг',
                          style: TextStyle(fontSize: 12, color: theme.mutedText),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        key: const ValueKey('vehicle-lookup'),
                        onPressed: _lookingUp || !_isPlateValid ? null : _lookup,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 40),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          textStyle: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          shape: const StadiumBorder(),
                        ),
                        child: _lookingUp
                            ? const SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('ХУР-аас хайх'),
                      ),
                    ],
                  ),
                  if (_lookupMessage != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: theme.successSoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _lookupMessage!,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.readable(
                            AppColors.green,
                            Theme.of(context).brightness,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  _Labeled(
                    label: 'Марк',
                    child: TextField(
                      key: const ValueKey('vehicle-make'),
                      controller: _makeController,
                      textCapitalization: TextCapitalization.words,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _Labeled(
                          label: 'Загвар',
                          child: TextField(
                            key: const ValueKey('vehicle-model'),
                            controller: _modelController,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 104,
                        child: _Labeled(
                          label: 'Он',
                          child: TextField(
                            key: const ValueKey('vehicle-year'),
                            controller: _yearController,
                            keyboardType: TextInputType.number,
                            style: csMono(fontSize: 16, color: theme.ink),
                            decoration: const InputDecoration(hintText: 'Заавал биш'),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _Labeled(
                    label: 'VIN (заавал биш)',
                    child: TextField(
                      key: const ValueKey('vehicle-vin'),
                      controller: _vinController,
                      textCapitalization: TextCapitalization.characters,
                      style: csMono(fontSize: 15, color: theme.ink),
                    ),
                  ),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      // The CTA stays pinned at the bottom, as on the CustSetup board.
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: FilledButton.icon(
            key: const ValueKey('vehicle-submit'),
            onPressed: _submitting ? null : _submit,
            icon: const Icon(Icons.directions_car_outlined),
            label: Text(_submitting ? 'Хадгалж байна…' : 'Нэмэх'),
          ),
        ),
      ),
    );
  }

  void _scheduleLookup(String value) {
    setState(() => _isPlateValid = _isValidPlate(value));
    _lookupTimer?.cancel();
    final plate = value.trim();
    if (!_isValidPlate(plate) || plate == _lastLookedUpPlate) return;
    _lookupTimer = Timer(const Duration(milliseconds: 400), () {
      if (mounted &&
          !_lookingUp &&
          plate == _plateController.text.trim() &&
          plate != _lastLookedUpPlate) {
        _lookup();
      }
    });
  }

  Future<void> _lookup() async {
    final plate = _plateController.text.trim();
    if (!_isValidPlate(plate)) {
      setState(() => _error = 'Дугаараа 4 цифр, 3 кирилл үсгээр оруулна уу.');
      return;
    }
    _lastLookedUpPlate = plate;
    setState(() {
      _lookingUp = true;
      _lookupMessage = null;
      _error = null;
    });
    try {
      final result = await widget.repository.lookupByPlate(plate);
      if (!mounted) return;
      setState(() {
        _makeController.text = result.make;
        _modelController.text = result.model;
        _yearController.text = result.year?.toString() ?? '';
        _vinController.text = result.vin ?? '';
        _fuelType = result.fuelType;
        _wheelPosition = result.wheelPosition;
        _colorName = result.colorName;
        _capacity = result.capacity;
        _purpose = result.purpose;
        _lookupMessage = result.source == VehicleLookupSource.hur
            ? 'ХУР-аас олдлоо. Мэдээллээ шалгаад засварлаж болно.'
            : 'Системээс олдлоо. Мэдээллээ шалгаад засварлаж болно.';
      });
    } on AppFailure catch (failure) {
      if (mounted) setState(() => _error = failure.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Тодорхойгүй алдаа гарлаа.');
    } finally {
      if (mounted) setState(() => _lookingUp = false);
    }
  }

  Future<void> _submit() async {
    final plate = _plateController.text.trim();
    final make = _makeController.text.trim();
    final model = _modelController.text.trim();
    if (!_isValidPlate(plate) || make.isEmpty || model.isEmpty) {
      setState(() => _error = 'Дугаар, марк, загвараа зөв оруулна уу.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final vehicle = await widget.repository.addVehicle(
        plate: plate,
        make: make,
        model: model,
        year: int.tryParse(_yearController.text.trim()),
        vin: _vinController.text.trim().isEmpty
            ? null
            : _vinController.text.trim(),
        fuelType: _fuelType,
        wheelPosition: _wheelPosition,
        colorName: _colorName,
        capacity: _capacity,
        purpose: _purpose,
      );
      if (mounted) widget.onAdded(vehicle);
    } on AppFailure catch (failure) {
      if (mounted) setState(() => _error = failure.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Тодорхойгүй алдаа гарлаа.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

/// A field label above its control (13px, w500).
class _Labeled extends StatelessWidget {
  const _Labeled({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
      const SizedBox(height: 6),
      child,
    ],
  );
}

/// The licence-plate frame: a navy "MNG" strip and a 2px ink outline.
class _PlateField extends StatelessWidget {
  const _PlateField({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = CarserviceTheme.of(context);
    return Container(
      height: 58,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.ink, width: 2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ExcludeSemantics(
            child: Container(
              width: 34,
              alignment: Alignment.center,
              color: theme.hero,
              child: Text(
                'MNG',
                style: csMono(fontSize: 9, color: theme.onHero),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              // Balance the strip so the plate reads optically centred.
              padding: const EdgeInsets.only(right: 34),
              child: Center(child: child),
            ),
          ),
        ],
      ),
    );
  }
}

bool _isValidPlate(String value) => _platePattern.hasMatch(value.trim());

class _MongolianPlateInputFormatter extends TextInputFormatter {
  const _MongolianPlateInputFormatter();

  static const _latinToCyrillic = {
    'A': 'А',
    'B': 'В',
    'C': 'С',
    'E': 'Е',
    'H': 'Н',
    'K': 'К',
    'M': 'М',
    'O': 'О',
    'P': 'Р',
    'T': 'Т',
    'X': 'Х',
    'Y': 'У',
  };

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final normalized = StringBuffer();
    for (final rune in newValue.text.toUpperCase().runes) {
      final character = String.fromCharCode(rune);
      if (!RegExp(r'[0-9A-ZА-ЯЁӨҮ]').hasMatch(character)) continue;
      normalized.write(_latinToCyrillic[character] ?? character);
      if (normalized.length == 7) break;
    }
    final value = normalized.toString();
    return TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }
}
