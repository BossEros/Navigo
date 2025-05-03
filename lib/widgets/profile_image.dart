// Updated profile_image.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:project_navigo/services/user_provider.dart';

class ProfileImageWidget extends StatelessWidget {
  final String? imageUrl;
  final double size;
  final bool isLoading;

  const ProfileImageWidget({
    Key? key,
    this.imageUrl,
    required this.size,
    this.isLoading = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: Colors.white, width: 4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipOval(
        child: isLoading
            ? _buildLoadingIndicator()
            : _buildProfileImage(context),
      ),
    );
  }

  Widget _buildProfileImage(BuildContext context) {
    // Check if we should use the preloaded image from UserProvider
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      // Get the UserProvider
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final preloadedImageProvider = userProvider.profileImageProvider;

      // Check if this image URL matches the preloaded one
      final isPreloadedImage = userProvider.isProfileImagePreloaded &&
          preloadedImageProvider != null &&
          userProvider.userProfile?.profileImageUrl == imageUrl;

      // Use the preloaded image if available, otherwise load normally
      if (isPreloadedImage) {
        return Image(
          image: preloadedImageProvider!,
          fit: BoxFit.cover,
          width: size,
          height: size,
          errorBuilder: (context, error, stackTrace) {
            return _buildFallbackIcon();
          },
        );
      } else {
        // Fall back to normal loading if URLs don't match
        return Image.network(
          imageUrl!,
          fit: BoxFit.cover,
          width: size,
          height: size,
          // Add cacheWidth for better performance
          cacheWidth: (size * 2).toInt(),
          errorBuilder: (context, error, stackTrace) {
            return _buildFallbackIcon();
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;

            return Stack(
              alignment: Alignment.center,
              children: [
                Container(color: Colors.grey[200]),
                CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                      loadingProgress.expectedTotalBytes!
                      : null,
                  strokeWidth: 2,
                ),
              ],
            );
          },
        );
      }
    } else {
      return _buildFallbackIcon();
    }
  }

  Widget _buildFallbackIcon() {
    return Icon(
      Icons.person,
      size: size * 0.5,
      color: Colors.grey[400],
    );
  }

  Widget _buildLoadingIndicator() {
    return Container(
      color: Colors.grey[200],
      child: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}