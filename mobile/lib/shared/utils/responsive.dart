import 'package:flutter/material.dart';

class ResponsiveUtils {
  // Breakpoint constants
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 1024;
  static const double desktopBreakpoint = 1440;
  
  // Get screen size
  static Size getScreenSize(BuildContext context) {
    return MediaQuery.of(context).size;
  }
  
  // Get screen width
  static double getScreenWidth(BuildContext context) {
    return MediaQuery.of(context).size.width;
  }
  
  // Get screen height
  static double getScreenHeight(BuildContext context) {
    return MediaQuery.of(context).size.height;
  }
  
  // Check if mobile
  static bool isMobile(BuildContext context) {
    return getScreenWidth(context) < mobileBreakpoint;
  }
  
  // Check if tablet
  static bool isTablet(BuildContext context) {
    final width = getScreenWidth(context);
    return width >= mobileBreakpoint && width < tabletBreakpoint;
  }
  
  // Check if desktop
  static bool isDesktop(BuildContext context) {
    return getScreenWidth(context) >= tabletBreakpoint;
  }
  
  // Get device type
  static DeviceType getDeviceType(BuildContext context) {
    final width = getScreenWidth(context);
    if (width < mobileBreakpoint) {
      return DeviceType.mobile;
    } else if (width < tabletBreakpoint) {
      return DeviceType.tablet;
    } else {
      return DeviceType.desktop;
    }
  }
  
  // Responsive value based on screen size
  static T responsiveValue<T>({
    required BuildContext context,
    required T mobile,
    T? tablet,
    T? desktop,
  }) {
    final deviceType = getDeviceType(context);
    switch (deviceType) {
      case DeviceType.mobile:
        return mobile;
      case DeviceType.tablet:
        return tablet ?? mobile;
      case DeviceType.desktop:
        return desktop ?? tablet ?? mobile;
    }
  }
  
  // Responsive margin/padding
  static EdgeInsets responsiveMargin({
    required BuildContext context,
    double mobile = 16.0,
    double tablet = 24.0,
    double desktop = 32.0,
  }) {
    final value = responsiveValue<double>(
      context: context,
      mobile: mobile,
      tablet: tablet,
      desktop: desktop,
    );
    return EdgeInsets.all(value);
  }
  
  static EdgeInsets responsiveMarginSymmetric({
    required BuildContext context,
    double horizontalMobile = 16.0,
    double verticalMobile = 16.0,
    double horizontalTablet = 24.0,
    double verticalTablet = 24.0,
    double horizontalDesktop = 32.0,
    double verticalDesktop = 32.0,
  }) {
    final horizontal = responsiveValue<double>(
      context: context,
      mobile: horizontalMobile,
      tablet: horizontalTablet,
      desktop: horizontalDesktop,
    );
    final vertical = responsiveValue<double>(
      context: context,
      mobile: verticalMobile,
      tablet: verticalTablet,
      desktop: verticalDesktop,
    );
    return EdgeInsets.symmetric(horizontal: horizontal, vertical: vertical);
  }
  
  // Responsive font size
  static double responsiveFontSize({
    required BuildContext context,
    required double mobile,
    double? tablet,
    double? desktop,
  }) {
    return responsiveValue<double>(
      context: context,
      mobile: mobile,
      tablet: tablet,
      desktop: desktop,
    );
  }
  
  // Responsive icon size
  static double responsiveIconSize({
    required BuildContext context,
    required double mobile,
    double? tablet,
    double? desktop,
  }) {
    return responsiveValue<double>(
      context: context,
      mobile: mobile,
      tablet: tablet,
      desktop: desktop,
    );
  }
  
  // Responsive border radius
  static double responsiveBorderRadius({
    required BuildContext context,
    required double mobile,
    double? tablet,
    double? desktop,
  }) {
    return responsiveValue<double>(
      context: context,
      mobile: mobile,
      tablet: tablet,
      desktop: desktop,
    );
  }
  
  // Responsive spacing
  static double responsiveSpacing({
    required BuildContext context,
    required double mobile,
    double? tablet,
    double? desktop,
  }) {
    return responsiveValue<double>(
      context: context,
      mobile: mobile,
      tablet: tablet,
      desktop: desktop,
    );
  }
  
  // Responsive width percentage
  static double responsiveWidth({
    required BuildContext context,
    required double mobilePercentage,
    double? tabletPercentage,
    double? desktopPercentage,
  }) {
    final screenWidth = getScreenWidth(context);
    final percentage = responsiveValue<double>(
      context: context,
      mobile: mobilePercentage,
      tablet: tabletPercentage,
      desktop: desktopPercentage,
    );
    return screenWidth * (percentage / 100);
  }
  
  // Responsive height percentage
  static double responsiveHeight({
    required BuildContext context,
    required double mobilePercentage,
    double? tabletPercentage,
    double? desktopPercentage,
  }) {
    final screenHeight = getScreenHeight(context);
    final percentage = responsiveValue<double>(
      context: context,
      mobile: mobilePercentage,
      tablet: tabletPercentage,
      desktop: desktopPercentage,
    );
    return screenHeight * (percentage / 100);
  }
  
  // Responsive grid columns
  static int responsiveColumns({
    required BuildContext context,
    int mobile = 1,
    int tablet = 2,
    int desktop = 3,
  }) {
    return responsiveValue<int>(
      context: context,
      mobile: mobile,
      tablet: tablet,
      desktop: desktop,
    );
  }
  
  // Responsive item count per row
  static int itemsPerRow({
    required BuildContext context,
    int mobile = 1,
    int tablet = 2,
    int desktop = 3,
  }) {
    return responsiveValue<int>(
      context: context,
      mobile: mobile,
      tablet: tablet,
      desktop: desktop,
    );
  }
  
  // Responsive aspect ratio
  static double responsiveAspectRatio({
    required BuildContext context,
    double mobile = 1.0,
    double tablet = 1.5,
    double desktop = 2.0,
  }) {
    return responsiveValue<double>(
      context: context,
      mobile: mobile,
      tablet: tablet,
      desktop: desktop,
    );
  }
  
  // Responsive cross-axis count for GridView
  static int responsiveCrossAxisCount({
    required BuildContext context,
    int mobile = 1,
    int tablet = 2,
    int desktop = 3,
  }) {
    return responsiveValue<int>(
      context: context,
      mobile: mobile,
      tablet: tablet,
      desktop: desktop,
    );
  }
  
  // Responsive child aspect ratio for GridView
  static double responsiveChildAspectRatio({
    required BuildContext context,
    double mobile = 1.0,
    double tablet = 1.2,
    double desktop = 1.5,
  }) {
    return responsiveValue<double>(
      context: context,
      mobile: mobile,
      tablet: tablet,
      desktop: desktop,
    );
  }
}

// Device type enum
enum DeviceType {
  mobile,
  tablet,
  desktop,
}

// Responsive builder widget
class ResponsiveBuilder extends StatelessWidget {
  
  const ResponsiveBuilder({
    required this.builder, super.key,
  });
  final Widget Function(BuildContext context, DeviceType deviceType) builder;
  
  @override
  Widget build(BuildContext context) {
    final deviceType = ResponsiveUtils.getDeviceType(context);
    return builder(context, deviceType);
  }
}

// Responsive layout widget
class ResponsiveLayout extends StatelessWidget {
  
  const ResponsiveLayout({
    required this.mobile, super.key,
    this.tablet,
    this.desktop,
  });
  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;
  
  @override
  Widget build(BuildContext context) {
    final deviceType = ResponsiveUtils.getDeviceType(context);
    
    switch (deviceType) {
      case DeviceType.mobile:
        return mobile;
      case DeviceType.tablet:
        return tablet ?? mobile;
      case DeviceType.desktop:
        return desktop ?? tablet ?? mobile;
    }
  }
}

// Responsive container widget
class ResponsiveContainer extends StatelessWidget {
  
  const ResponsiveContainer({
    required this.child, super.key,
    this.width,
    this.height,
    this.padding,
    this.margin,
    this.decoration,
    this.alignment,
  });
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final Decoration? decoration;
  final Alignment? alignment;
  
  @override
  Widget build(BuildContext context) {
    final screenWidth = ResponsiveUtils.getScreenWidth(context);
    final deviceType = ResponsiveUtils.getDeviceType(context);
    
    double? containerWidth;
    if (width != null) {
      containerWidth = ResponsiveUtils.responsiveValue<double>(
        context: context,
        mobile: width!,
        tablet: width! * 1.2,
        desktop: width! * 1.5,
      );
    }
    
    // Limit max width on larger screens
    if (deviceType == DeviceType.desktop && containerWidth != null) {
      containerWidth = containerWidth.clamp(0, 1200);
    } else if (deviceType == DeviceType.desktop) {
      containerWidth = 1200;
    }
    
    return Container(
      width: containerWidth,
      height: height,
      padding: padding,
      margin: margin,
      decoration: decoration,
      alignment: alignment,
      child: child,
    );
  }
}

// Responsive grid view
class ResponsiveGridView extends StatelessWidget {
  
  const ResponsiveGridView({
    required this.children, super.key,
    this.gridDelegate,
    this.padding,
    this.shrinkWrap = false,
    this.controller,
    this.physics,
  });
  final List<Widget> children;
  final SliverGridDelegate? gridDelegate;
  final EdgeInsets? padding;
  final bool shrinkWrap;
  final ScrollController? controller;
  final Physics? physics;
  
  @override
  Widget build(BuildContext context) {
    final crossAxisCount = ResponsiveUtils.responsiveCrossAxisCount(context: context);
    final childAspectRatio = ResponsiveUtils.responsiveChildAspectRatio(context: context);
    
    return GridView.builder(
      padding: padding,
      shrinkWrap: shrinkWrap,
      controller: controller,
      physics: physics,
      gridDelegate: gridDelegate ??
          SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: childAspectRatio,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
      itemCount: children.length,
      itemBuilder: (context, index) => children[index],
    );
  }
}

// Responsive list view
class ResponsiveListView extends StatelessWidget {
  
  const ResponsiveListView({
    required this.children, super.key,
    this.padding,
    this.shrinkWrap = false,
    this.controller,
    this.physics,
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
  });
  final List<Widget> children;
  final EdgeInsets? padding;
  final bool shrinkWrap;
  final ScrollController? controller;
  final Physics? physics;
  final Axis scrollDirection;
  final bool reverse;
  
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: padding ?? ResponsiveUtils.responsiveMargin(context: context),
      shrinkWrap: shrinkWrap,
      controller: controller,
      physics: physics,
      scrollDirection: scrollDirection,
      reverse: reverse,
      children: children,
    );
  }
}

// Extension on BuildContext for responsive utilities
extension ResponsiveBuildContext on BuildContext {
  // Responsive value
  T responsive<T>({
    required T mobile,
    T? tablet,
    T? desktop,
  }) {
    return ResponsiveUtils.responsiveValue<T>(
      context: this,
      mobile: mobile,
      tablet: tablet,
      desktop: desktop,
    );
  }
  
  // Check device type
  bool get isMobile => ResponsiveUtils.isMobile(this);
  bool get isTablet => ResponsiveUtils.isTablet(this);
  bool get isDesktop => ResponsiveUtils.isDesktop(this);
  DeviceType get deviceType => ResponsiveUtils.getDeviceType(this);
  
  // Responsive dimensions
  double get screenWidth => ResponsiveUtils.getScreenWidth(this);
  double get screenHeight => ResponsiveUtils.getScreenHeight(this);
  Size get screenSize => ResponsiveUtils.getScreenSize(this);
}
