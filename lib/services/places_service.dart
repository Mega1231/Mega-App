import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class PlaceSuggestion {
  final String placeId;
  final String description;
  const PlaceSuggestion(this.placeId, this.description);
}

class PlaceDetails {
  final String address;
  final double latitude;
  final double longitude;
  const PlaceDetails(this.address, this.latitude, this.longitude);
}

/// Google Places API (New) address search, the same calls the mobile
/// create/edit user forms make.
class PlacesService {
  // Web uses its own referrer-restricted key, injected at build time.
  final String _apiKey = kIsWeb
      ? const String.fromEnvironment('MAPS_WEB_API_KEY')
      : dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';

  bool get isConfigured => _apiKey.isNotEmpty;

  Future<List<PlaceSuggestion>> autocomplete(String input) async {
    if (_apiKey.isEmpty || input.trim().length < 3) return const [];
    final response = await http.post(
      Uri.parse('https://places.googleapis.com/v1/places:autocomplete'),
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': _apiKey,
      },
      body: json.encode({'input': input.trim()}),
    );
    if (response.statusCode != 200) return const [];
    final suggestions = (json.decode(response.body)['suggestions'] as List?) ?? [];
    return [
      for (final s in suggestions)
        if (s['placePrediction'] != null)
          PlaceSuggestion(
            s['placePrediction']['placeId'] ?? '',
            s['placePrediction']['text']?['text'] ?? '',
          ),
    ];
  }

  Future<PlaceDetails?> details(PlaceSuggestion suggestion) async {
    final response = await http.get(
      Uri.parse('https://places.googleapis.com/v1/places/${suggestion.placeId}'),
      headers: {
        'X-Goog-Api-Key': _apiKey,
        'X-Goog-FieldMask': 'formattedAddress,location',
      },
    );
    if (response.statusCode != 200) return null;
    final data = json.decode(response.body);
    final location = data['location'];
    if (location == null) return null;
    return PlaceDetails(
      data['formattedAddress'] as String? ?? suggestion.description,
      (location['latitude'] as num).toDouble(),
      (location['longitude'] as num).toDouble(),
    );
  }
}
