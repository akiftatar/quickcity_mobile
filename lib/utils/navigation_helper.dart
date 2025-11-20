import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../models/location.dart';
import '../widgets/navigation_bottom_sheet.dart';

class NavigationHelper {
  /// Bottom sheet ile navigasyon önizlemesi aç
  static Future<void> showNavigationBottomSheet(BuildContext context, Location location) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => NavigationBottomSheet(location: location),
    );
  }

  /// Google Maps ile navigasyon aç (Otomatik araç modu)
  static Future<void> openInMaps(BuildContext context, Location location) async {
    final l10n = AppLocalizations.of(context)!;
    
    try {
      // Google Maps URL'sini oluştur - ARAÇ MODU AKTİF
      final googleMapsUrl = 'https://www.google.com/maps/dir/?api=1&destination=${location.lat},${location.lng}&travelmode=driving';
      final uri = Uri.parse(googleMapsUrl);
      
      if (await canLaunchUrl(uri)) {
        // Google Maps uygulamasını aç (eğer yüklüyse) - ARAÇ MODU
        final googleMapsAppUrl = 'comgooglemaps://?daddr=${location.lat},${location.lng}&directionsmode=driving';
        final googleMapsAppUri = Uri.parse(googleMapsAppUrl);
        
        if (await canLaunchUrl(googleMapsAppUri)) {
          // Google Maps uygulaması yüklü, uygulamayı aç
          await launchUrl(googleMapsAppUri, mode: LaunchMode.externalApplication);
          
          // Başarı mesajı
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${l10n.navigateTo} ${location.formattedAddress}'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        } else {
          // Google Maps uygulaması yüklü değil, web tarayıcısında aç
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          
          // Başarı mesajı
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${l10n.navigateTo} ${location.formattedAddress}'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        }
      } else {
        throw Exception(l10n.googleMapsError);
      }
    } catch (e) {
      // Hata durumunda kullanıcıya bilgi ver
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.navigateTo} ${location.formattedAddress}'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: l10n.open,
              textColor: Colors.white,
              onPressed: () async {
                try {
                  final googleMapsUrl = 'https://www.google.com/maps/dir/?api=1&destination=${location.lat},${location.lng}';
                  final uri = Uri.parse(googleMapsUrl);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                } catch (e) {
                  // Hata durumunda hiçbir şey yapma
                }
              },
            ),
          ),
        );
      }
    }
  }

  /// Navigasyon butonu widget'ı oluştur
  static Widget buildNavigationButton({
    required BuildContext context,
    required Location location,
    required VoidCallback onPressed,
    bool isExpanded = false,
    bool isEnabled = true,
  }) {
    final l10n = AppLocalizations.of(context)!;
    
    final button = ElevatedButton.icon(
      onPressed: isEnabled ? onPressed : null,
      icon: const Icon(Icons.navigation, size: 16),
      label: Text(l10n.navigation),
      style: ElevatedButton.styleFrom(
        backgroundColor: isEnabled ? Colors.green : Colors.grey,
        foregroundColor: Colors.white,
        disabledBackgroundColor: Colors.grey[300],
        disabledForegroundColor: Colors.grey[600],
      ),
    );

    if (isExpanded) {
      return Expanded(child: button);
    }
    
    return button;
  }

  /// Navigasyon action butonu (Slidable için)
  static Widget buildNavigationAction({
    required BuildContext context,
    required Location location,
    required VoidCallback onPressed,
    bool isEnabled = true,
  }) {
    final l10n = AppLocalizations.of(context)!;
    
    return SlidableAction(
      onPressed: isEnabled ? (_) => onPressed() : null,
      backgroundColor: isEnabled ? Colors.green : Colors.grey,
      foregroundColor: Colors.white,
      icon: Icons.navigation,
      label: l10n.navigate,
    );
  }
}
