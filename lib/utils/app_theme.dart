import 'package:flutter/material.dart';

/// EduVerse App Theme - Consistent colors and styles across the app
class AppTheme {
  // Primary Colors
  static const Color primaryColor = Color(0xFF1A237E); // Deep Indigo
  static const Color primaryLight = Color(0xFF534bae);
  static const Color primaryDark = Color(0xFF000051);

  // Accent Colors
  static const Color accentColor = Color(0xFF00BFA5); // Teal accent
  static const Color accentLight = Color(0xFF5df2d6);
  static const Color accentDark = Color(0xFF008e76);

  // Background Colors
  static const Color backgroundColor = Color(0xFFF5F7FA);
  static const Color surfaceColor = Colors.white;
  static const Color cardColor = Colors.white;

  // ===== PREMIUM DARK THEME - METALLIC STYLE =====
  // Metallic gray-blue base with better contrast (NOT pure black)
  static const Color darkBackground = Color(0xFF1A1D24); // Metallic dark gray
  static const Color darkSurface = Color(
    0xFF22262F,
  ); // Elevated metallic surface
  static const Color darkCard = Color(0xFF2A2F3A); // Card - lighter metallic
  static const Color darkElevated = Color(
    0xFF343A47,
  ); // Higher elevation - steel
  static const Color darkHighlight = Color(
    0xFF3E4555,
  ); // Highlight/hover - silver tint

  // Dark theme text colors with optimal contrast
  static const Color darkTextPrimary = Color(0xFFE6EDF3); // Near-white, soft
  static const Color darkTextSecondary = Color(0xFF9BA4B5); // Muted gray-blue
  static const Color darkTextTertiary = Color(0xFF6B7689); // Disabled/hint text

  // Dark theme borders and dividers - more visible with metallic look
  static const Color darkBorder = Color(0xFF3D4350); // Visible metallic border
  static const Color darkDivider = Color(0xFF2F343E); // Subtle metallic divider

  // Dark theme accent colors - Electric, Vibrant, Glowing
  static const Color darkPrimary = Color(0xFF4CC9F0); // Electric Cyan
  static const Color darkPrimaryLight = Color(0xFF72EFDD); // Light cyan-teal
  static const Color darkAccent = Color(0xFF2EC4B6); // Vibrant Teal
  static const Color darkAccentAlt = Color(0xFF7B68EE); // Violet accent
  static const Color darkSecondary = Color(0xFF4895EF); // Electric Blue

  // Glow/Highlight colors for premium feel
  static const Color darkGlow = Color(0xFF00D9FF); // Neon cyan glow
  static const Color darkGlowAlt = Color(0xFF9D4EDD); // Neon violet glow

  // Metallic/Premium accents
  static const Color darkGold = Color(0xFFE3B341); // Premium gold
  static const Color darkSilver = Color(0xFFC9D1D9); // Silver accent

  // Status colors for dark mode - brighter for visibility
  static const Color darkSuccess = Color(0xFF4ADE80); // Bright green
  static const Color darkError = Color(0xFFFF6B6B); // Coral red
  static const Color darkWarning = Color(0xFFFFBE0B); // Bright amber
  static const Color darkInfo = Color(0xFF4CC9F0); // Cyan info

  // Legacy dark theme color names for backward compatibility
  static const Color darkBackgroundColor = darkBackground;
  static const Color darkSurfaceColor = darkSurface;
  static const Color darkCardColor = darkCard;
  static const Color darkTextPrimary_old = darkTextPrimary;
  static const Color darkTextSecondary_old = darkTextSecondary;
  static const Color darkBorderColor = darkBorder;
  static const Color darkAccentColor = darkAccent;

  // Text Colors
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textOnPrimary = Colors.white;

  // Status Colors
  static const Color success = Color(0xFF4CAF50);
  static const Color error = Color(0xFFE53935);
  static const Color warning = Color(0xFFFFA726);
  static const Color info = Color(0xFF29B6F6);

  // ===== CONTEXT-AWARE COLOR HELPERS =====

  /// Get background color based on theme
  static Color getBackgroundColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkBackground
        : backgroundColor;
  }

  /// Get surface/card color based on theme
  static Color getSurfaceColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkSurface
        : surfaceColor;
  }

  /// Get card color based on theme
  static Color getCardColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkCard
        : cardColor;
  }

  /// Get elevated card color (higher elevation)
  static Color getElevatedColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkElevated
        : cardColor;
  }

  /// Get highlight/hover state color based on theme
  static Color getHighlightStateColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkHighlight
        : Colors.grey.shade100;
  }

  /// Get primary text color based on theme
  static Color getTextPrimary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkTextPrimary
        : textPrimary;
  }

  /// Get secondary text color based on theme
  static Color getTextSecondary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkTextSecondary
        : textSecondary;
  }

  /// Get hint/disabled text color based on theme
  static Color getTextHint(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkTextTertiary
        : Colors.grey.shade400;
  }

  /// Get border color based on theme
  static Color getBorderColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkBorder
        : Colors.grey.shade300;
  }

  /// Get divider color based on theme
  static Color getDividerColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkDivider
        : Colors.grey.shade200;
  }

  /// Get highlight color for selected items
  static Color getHighlightColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkPrimary.withOpacity(0.2)
        : primaryColor.withOpacity(0.1);
  }

  /// Get accent color based on theme
  static Color getAccentColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkAccent
        : accentColor;
  }

  /// Get button color - uses teal accent for consistent look in dark mode
  static Color getButtonColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkAccent // Vibrant Teal for buttons in dark mode
        : primaryColor;
  }

  /// Get button text color - softer white for less harsh look
  static Color getButtonTextColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFF0F8FF) // Soft white with blue tint
        : const Color(0xFFF5F5F5); // Soft white
  }

  /// Get button shadow color for glow effect
  static Color getButtonShadowColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkAccent.withOpacity(0.5)
        : primaryColor.withOpacity(0.4);
  }

  /// Get button box decoration with glow effect
  static BoxDecoration getButtonDecoration(
    BuildContext context, {
    Color? color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final buttonColor = color ?? (isDark ? darkAccent : primaryColor);
    return BoxDecoration(
      color: buttonColor,
      borderRadius: BorderRadius.circular(18),
      boxShadow: [
        BoxShadow(
          color: buttonColor.withOpacity(isDark ? 0.28 : 0.22),
          blurRadius: isDark ? 10 : 6,
          spreadRadius: isDark ? 0.6 : 0,
          offset: const Offset(0, 3),
        ),
        if (isDark)
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 14,
            spreadRadius: -6,
            offset: const Offset(0, 2),
          ),
      ],
    );
  }

  /// Get styled button (ElevatedButton.styleFrom) with consistent glow
  static ButtonStyle getElevatedButtonStyle(
    BuildContext context, {
    Color? backgroundColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = backgroundColor ?? (isDark ? darkAccent : primaryColor);
    return ElevatedButton.styleFrom(
      backgroundColor: bgColor,
      foregroundColor: isDark ? const Color(0xFFF5FAFF) : const Color(0xFFF5F5F5),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      elevation: isDark ? 4 : 4,
      shadowColor: bgColor.withOpacity(isDark ? 0.28 : 0.32),
      textStyle: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        letterSpacing: isDark ? 0.4 : 0.5,
      ),
    );
  }

  /// Get button gradient for premium button styling
  static LinearGradient getButtonGradient(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark
        ? const LinearGradient(
            colors: [Color(0xFF2EC4B6), Color(0xFF22A094)], // Teal gradient
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : primaryGradient;
  }

  /// Get primary color based on theme (for interactive elements)
  static Color getPrimaryColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkPrimary
        : primaryColor;
  }

  /// Get secondary color for dark mode
  static Color getSecondaryColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkSecondary
        : primaryLight;
  }

  /// Get icon color based on theme
  static Color getIconColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkTextPrimary
        : textPrimary;
  }

  /// Get secondary icon color based on theme
  static Color getIconSecondary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkTextSecondary
        : textSecondary;
  }

  /// Get glow color for premium effects
  static Color getGlowColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkGlow
        : primaryColor;
  }

  /// Check if dark mode is active
  static bool isDarkMode(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }

  /// Get status color based on theme
  static Color getSuccessColor(BuildContext context) {
    return isDarkMode(context) ? darkSuccess : success;
  }

  static Color getErrorColor(BuildContext context) {
    return isDarkMode(context) ? darkError : error;
  }

  static Color getWarningColor(BuildContext context) {
    return isDarkMode(context) ? darkWarning : warning;
  }

  static Color getInfoColor(BuildContext context) {
    return isDarkMode(context) ? darkInfo : info;
  }

  /// Get card decoration with proper theme-aware styling - METALLIC DARK LOOK
  static BoxDecoration getCardDecoration(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      gradient: isDark
          ? const LinearGradient(
              colors: [Color(0xFF2E333D), Color(0xFF262B35)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            )
          : null,
      color: isDark ? null : cardColor,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: isDark ? darkBorder.withOpacity(0.8) : Colors.grey.shade200,
        width: 1,
      ),
      boxShadow: isDark
          ? [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 12,
                spreadRadius: -2,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: Colors.white.withOpacity(0.02),
                blurRadius: 1,
                offset: const Offset(0, -1),
              ),
            ]
          : [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
    );
  }

  /// Get elevated card decoration (more prominent) - METALLIC DARK LOOK
  static BoxDecoration getElevatedCardDecoration(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      gradient: isDark
          ? const LinearGradient(
              colors: [Color(0xFF383E4A), Color(0xFF2E333D)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            )
          : null,
      color: isDark ? null : cardColor,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: isDark ? darkBorder : Colors.grey.shade200,
        width: 1,
      ),
      boxShadow: isDark
          ? [
              BoxShadow(
                color: Colors.black.withOpacity(0.35),
                blurRadius: 16,
                spreadRadius: -2,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: Colors.white.withOpacity(0.03),
                blurRadius: 2,
                offset: const Offset(0, -1),
              ),
            ]
          : [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 15,
                offset: const Offset(0, 4),
              ),
            ],
    );
  }

  /// Get glowing card decoration for featured items - Metallic style
  static BoxDecoration getGlowingCardDecoration(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      gradient: isDark
          ? const LinearGradient(
              colors: [Color(0xFF3A4556), Color(0xFF2E3A4A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            )
          : null,
      color: isDark ? null : cardColor,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: isDark ? darkPrimary.withOpacity(0.4) : Colors.grey.shade200,
        width: 1.5,
      ),
      boxShadow: isDark
          ? [
              BoxShadow(
                color: darkPrimary.withOpacity(0.12),
                blurRadius: 20,
                spreadRadius: -2,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: Colors.white.withOpacity(0.03),
                blurRadius: 1,
                offset: const Offset(0, -1),
              ),
            ]
          : [
              BoxShadow(
                color: primaryColor.withOpacity(0.15),
                blurRadius: 15,
                offset: const Offset(0, 4),
              ),
            ],
    );
  }

  /// Get input field decoration for dark mode - Metallic
  static BoxDecoration getInputDecoration(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: isDark ? darkElevated : Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: isDark ? darkBorder : Colors.grey.shade300,
        width: 1,
      ),
    );
  }

  /// Get focused input field decoration for dark mode
  static BoxDecoration getFocusedInputDecoration(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: isDark ? darkElevated : Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: isDark ? darkPrimary : primaryColor, width: 2),
      boxShadow: isDark
          ? [
              BoxShadow(
                color: darkPrimary.withOpacity(0.2),
                blurRadius: 8,
                spreadRadius: -2,
              ),
            ]
          : null,
    );
  }

  // Gradient
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryColor, primaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Dark mode gradient - Metallic blue-gray
  static const LinearGradient darkPrimaryGradient = LinearGradient(
    colors: [Color(0xFF2C3E50), Color(0xFF34495E), Color(0xFF415B76)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    stops: [0.0, 0.5, 1.0],
  );

  /// Dark mode accent gradient - Metallic teal
  static const LinearGradient darkAccentGradient = LinearGradient(
    colors: [Color(0xFF1E4D4D), Color(0xFF2A6B6B), Color(0xFF348888)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    stops: [0.0, 0.5, 1.0],
  );

  /// Metallic steel gradient for featured items
  static const LinearGradient darkNeonGradient = LinearGradient(
    colors: [Color(0xFF3A4556), Color(0xFF4A5568), Color(0xFF5A6A7A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Purple metallic gradient
  static const LinearGradient darkPurpleGradient = LinearGradient(
    colors: [Color(0xFF3D3A5C), Color(0xFF4E4A70), Color(0xFF5F5A85)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Metallic surface gradient for cards
  static const LinearGradient darkSurfaceGradient = LinearGradient(
    colors: [Color(0xFF2E333D), Color(0xFF343A47)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Get gradient based on theme
  static LinearGradient getGradient(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkPrimaryGradient
        : primaryGradient;
  }

  /// Get accent gradient based on theme
  static LinearGradient getAccentGradient(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkAccentGradient
        : accentGradient;
  }

  static const LinearGradient accentGradient = LinearGradient(
    colors: [accentColor, accentLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Theme Data
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        primary: primaryColor,
        secondary: accentColor,
        surface: surfaceColor,
        error: error,
      ),
      scaffoldBackgroundColor: backgroundColor,

      // AppBar Theme
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: textOnPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: textOnPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),

      // Card Theme
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 2,
        shadowColor: Colors.black12,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      // Elevated Button Theme - with subtle shadow
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: const Color(0xFFF5F5F5), // Softer white
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 4,
          shadowColor: primaryColor.withOpacity(0.4),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),

      // Text Button Theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),

      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceColor,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: error),
        ),
        prefixIconColor: textSecondary,
      ),

      // Bottom Navigation Bar Theme
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: primaryColor,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white60,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),

      // Floating Action Button Theme
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: accentColor,
        foregroundColor: Colors.white,
        elevation: 4,
      ),

      // Tab Bar Theme
      tabBarTheme: const TabBarThemeData(
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white60,
        indicatorColor: accentColor,
        indicatorSize: TabBarIndicatorSize.tab,
      ),

      // Snackbar Theme
      snackBarTheme: SnackBarThemeData(
        backgroundColor: textPrimary,
        contentTextStyle: const TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),

      // Dialog Theme
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  // Dark Theme Data - PREMIUM AUTOMOTIVE DASHBOARD STYLE
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: darkPrimary,
        onPrimary: const Color(0xFF0B0F1A), // Dark text on bright primary
        secondary: darkAccent,
        onSecondary: const Color(0xFF0B0F1A),
        tertiary: darkSecondary,
        surface: darkSurface,
        onSurface: darkTextPrimary,
        error: darkError,
        onError: const Color(0xFF0B0F1A),
        primaryContainer: darkCard,
        onPrimaryContainer: darkTextPrimary,
        secondaryContainer: darkElevated,
        onSecondaryContainer: darkTextPrimary,
        outline: darkBorder,
        outlineVariant: darkDivider,
        shadow: Colors.black,
      ),
      scaffoldBackgroundColor: darkBackground,

      // AppBar Theme - Premium dark gradient header
      appBarTheme: AppBarTheme(
        backgroundColor: darkSurface,
        foregroundColor: darkTextPrimary,
        elevation: 0,
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black.withOpacity(0.3),
        titleTextStyle: const TextStyle(
          color: darkTextPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
        iconTheme: const IconThemeData(color: darkTextPrimary, size: 26),
      ),

      // Card Theme - Premium floating cards with glow
      cardTheme: CardThemeData(
        color: darkCard,
        elevation: 8,
        shadowColor: Colors.black.withOpacity(0.5),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: darkBorder.withOpacity(0.6), width: 1),
        ),
      ),

      // Elevated Button Theme - Vibrant teal buttons with glow effect
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: darkAccent, // Vibrant Teal - consistent across app
          foregroundColor: const Color(
            0xFFF0F8FF,
          ), // Softer white with slight blue tint
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 28),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 8,
          shadowColor: darkAccent.withOpacity(0.5),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
        ),
      ),

      // Outlined Button Theme - Glowing borders
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: darkPrimary,
          side: const BorderSide(color: darkPrimary, width: 2),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 28),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),

      // Text Button Theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: darkPrimary,
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ),

      // Input Decoration Theme - Premium glassmorphism style
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkElevated,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: darkBorder, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: darkBorder, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: darkPrimary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: darkError, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: darkError, width: 2),
        ),
        prefixIconColor: darkTextSecondary,
        suffixIconColor: darkTextSecondary,
        hintStyle: const TextStyle(color: darkTextTertiary, fontSize: 15),
        labelStyle: const TextStyle(color: darkTextSecondary, fontSize: 15),
        errorStyle: const TextStyle(color: darkError, fontSize: 13),
        floatingLabelStyle: const TextStyle(color: darkPrimary),
      ),

      // Bottom Navigation Bar Theme - Premium with glow
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: darkSurface,
        selectedItemColor: darkPrimary,
        unselectedItemColor: darkTextTertiary,
        type: BottomNavigationBarType.fixed,
        elevation: 16,
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 11,
        ),
        selectedIconTheme: IconThemeData(
          color: darkPrimary,
          size: 28,
          shadows: [Shadow(color: darkPrimary.withOpacity(0.4), blurRadius: 8)],
        ),
        unselectedIconTheme: const IconThemeData(
          color: darkTextTertiary,
          size: 24,
        ),
      ),

      // Navigation Bar Theme (Material 3) - Premium with glow indicator
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: darkSurface,
        indicatorColor: darkPrimary.withOpacity(0.25),
        elevation: 8,
        shadowColor: Colors.black,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              color: darkPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            );
          }
          return const TextStyle(color: darkTextSecondary, fontSize: 12);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: darkPrimary);
          }
          return const IconThemeData(color: darkTextSecondary);
        }),
      ),

      // Floating Action Button Theme
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: darkAccent,
        foregroundColor: darkBackground,
        elevation: 4,
        focusElevation: 6,
        hoverElevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      // Tab Bar Theme
      tabBarTheme: const TabBarThemeData(
        labelColor: darkPrimary,
        unselectedLabelColor: darkTextSecondary,
        indicatorColor: darkPrimary,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelStyle: TextStyle(fontWeight: FontWeight.w600),
      ),

      // Snackbar Theme
      snackBarTheme: SnackBarThemeData(
        backgroundColor: darkElevated,
        contentTextStyle: const TextStyle(color: darkTextPrimary),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: darkBorder),
        ),
        elevation: 8,
      ),

      // Dialog Theme
      dialogTheme: DialogThemeData(
        backgroundColor: darkSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: darkBorder),
        ),
        elevation: 24,
        titleTextStyle: const TextStyle(
          color: darkTextPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: const TextStyle(
          color: darkTextSecondary,
          fontSize: 14,
        ),
      ),

      // Icon Theme - Visible on dark backgrounds
      iconTheme: const IconThemeData(color: darkTextPrimary, size: 24),

      // Primary Icon Theme
      primaryIconTheme: const IconThemeData(color: darkPrimary, size: 24),

      // Text Theme - Proper contrast hierarchy
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          color: darkTextPrimary,
          fontWeight: FontWeight.bold,
        ),
        displayMedium: TextStyle(
          color: darkTextPrimary,
          fontWeight: FontWeight.bold,
        ),
        displaySmall: TextStyle(
          color: darkTextPrimary,
          fontWeight: FontWeight.bold,
        ),
        headlineLarge: TextStyle(
          color: darkTextPrimary,
          fontWeight: FontWeight.w600,
        ),
        headlineMedium: TextStyle(
          color: darkTextPrimary,
          fontWeight: FontWeight.w600,
        ),
        headlineSmall: TextStyle(
          color: darkTextPrimary,
          fontWeight: FontWeight.w600,
        ),
        titleLarge: TextStyle(
          color: darkTextPrimary,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: TextStyle(
          color: darkTextPrimary,
          fontWeight: FontWeight.w500,
        ),
        titleSmall: TextStyle(
          color: darkTextPrimary,
          fontWeight: FontWeight.w500,
        ),
        bodyLarge: TextStyle(color: darkTextPrimary),
        bodyMedium: TextStyle(color: darkTextPrimary),
        bodySmall: TextStyle(color: darkTextSecondary),
        labelLarge: TextStyle(
          color: darkTextPrimary,
          fontWeight: FontWeight.w600,
        ),
        labelMedium: TextStyle(color: darkTextSecondary),
        labelSmall: TextStyle(color: darkTextTertiary),
      ),

      // Chip Theme
      chipTheme: ChipThemeData(
        backgroundColor: darkElevated,
        disabledColor: darkCard,
        selectedColor: darkPrimary.withOpacity(0.2),
        secondarySelectedColor: darkAccent.withOpacity(0.2),
        labelStyle: const TextStyle(color: darkTextPrimary),
        secondaryLabelStyle: const TextStyle(color: darkTextSecondary),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: darkBorder),
        ),
      ),

      // List Tile Theme
      listTileTheme: const ListTileThemeData(
        textColor: darkTextPrimary,
        iconColor: darkTextSecondary,
        tileColor: Colors.transparent,
        selectedTileColor: Color(0xFF1E3A5F),
        selectedColor: darkPrimary,
      ),

      // Switch Theme
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return darkPrimary;
          }
          return darkTextSecondary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return darkPrimary.withOpacity(0.4);
          }
          return darkElevated;
        }),
        trackOutlineColor: WidgetStateProperty.all(darkBorder),
      ),

      // Checkbox Theme
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return darkPrimary;
          }
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(darkBackground),
        side: const BorderSide(color: darkTextSecondary, width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),

      // Radio Theme
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return darkPrimary;
          }
          return darkTextSecondary;
        }),
      ),

      // Slider Theme
      sliderTheme: SliderThemeData(
        activeTrackColor: darkPrimary,
        inactiveTrackColor: darkElevated,
        thumbColor: darkPrimary,
        overlayColor: darkPrimary.withOpacity(0.2),
        valueIndicatorColor: darkPrimary,
        valueIndicatorTextStyle: const TextStyle(color: darkBackground),
      ),

      // Progress Indicator Theme
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: darkPrimary,
        linearTrackColor: darkElevated,
        circularTrackColor: darkElevated,
      ),

      // Divider Theme
      dividerTheme: const DividerThemeData(
        color: darkDivider,
        thickness: 1,
        space: 1,
      ),

      // Popup Menu Theme
      popupMenuTheme: PopupMenuThemeData(
        color: darkSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: darkBorder),
        ),
        elevation: 8,
        textStyle: const TextStyle(color: darkTextPrimary),
      ),

      // Bottom Sheet Theme
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: darkSurface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        dragHandleColor: darkTextTertiary,
        dragHandleSize: Size(40, 4),
      ),

      // Drawer Theme
      drawerTheme: const DrawerThemeData(
        backgroundColor: darkSurface,
        surfaceTintColor: Colors.transparent,
        scrimColor: Colors.black54,
      ),

      // Tooltip Theme
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: darkElevated,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: darkBorder),
        ),
        textStyle: const TextStyle(color: darkTextPrimary),
      ),
    );
  }

  // Common Decorations
  static BoxDecoration get cardDecoration => BoxDecoration(
    color: cardColor,
    borderRadius: BorderRadius.circular(16),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.05),
        blurRadius: 10,
        offset: const Offset(0, 4),
      ),
    ],
  );

  static BoxDecoration get gradientDecoration =>
      const BoxDecoration(gradient: primaryGradient);

  // Text Styles
  static const TextStyle headingLarge = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: textPrimary,
    letterSpacing: 0.5,
  );

  static const TextStyle headingMedium = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );

  static const TextStyle headingSmall = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    color: textPrimary,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    color: textSecondary,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    color: textSecondary,
  );

  // Success Dialog
  static void showSuccessDialog({
    required BuildContext context,
    required String title,
    required String message,
    required VoidCallback onPressed,
    String buttonText = 'Continue',
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: success.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle, color: success, size: 60),
            ),
            const SizedBox(height: 20),
            Text(title, style: headingMedium, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Text(message, style: bodyMedium, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onPressed,
                child: Text(buttonText),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Loading Dialog
  static void showLoadingDialog(BuildContext context, {String? message}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Row(
          children: [
            const CircularProgressIndicator(color: primaryColor),
            const SizedBox(width: 20),
            Text(message ?? 'Please wait...'),
          ],
        ),
      ),
    );
  }
}
