import 'package:flutter/material.dart';
import 'package:vaxiil_mobile/shared/themes/app_theme.dart';
import 'package:vaxiil_mobile/shared/utils/responsive.dart';

// Primary button with loading state
class PrimaryButton extends StatelessWidget {
  
  const PrimaryButton({
    required this.text, super.key,
    this.onPressed,
    this.isLoading = false,
    this.isFullWidth = false,
    this.height,
    this.width,
    this.icon,
    this.backgroundColor,
    this.textColor,
    this.borderRadius,
    this.padding,
  });
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isFullWidth;
  final double? height;
  final double? width;
  final Widget? icon;
  final Color? backgroundColor;
  final Color? textColor;
  final double? borderRadius;
  final EdgeInsets? padding;
  
  @override
  Widget build(BuildContext context) {
    final responsiveHeight = height ?? ResponsiveUtils.responsiveSpacing(context: context, mobile: 48, tablet: 52, desktop: 56);
    final responsivePadding = padding ?? ResponsiveUtils.responsiveMarginSymmetric(context: context, horizontalMobile: 24, verticalMobile: 12);
    final responsiveBorderRadius = borderRadius ?? ResponsiveUtils.responsiveBorderRadius(context: context, mobile: 12, tablet: 14, desktop: 16);
    
    return SizedBox(
      width: isFullWidth ? double.infinity : width,
      height: responsiveHeight,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor ?? AppTheme.primaryColor,
          foregroundColor: textColor ?? AppTheme.textOnPrimary,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(responsiveBorderRadius),
          ),
          padding: responsivePadding,
        ),
        child: isLoading
            ? SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(textColor ?? AppTheme.textOnPrimary),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    icon!,
                    const SizedBox(width: 8),
                  ],
                  Text(
                    text,
                    style: TextStyle(
                      fontSize: ResponsiveUtils.responsiveFontSize(context: context, mobile: 16, tablet: 17, desktop: 18),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// Secondary button
class SecondaryButton extends StatelessWidget {
  
  const SecondaryButton({
    required this.text, super.key,
    this.onPressed,
    this.isLoading = false,
    this.isFullWidth = false,
    this.height,
    this.width,
    this.icon,
    this.borderColor,
    this.textColor,
    this.borderRadius,
    this.padding,
  });
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isFullWidth;
  final double? height;
  final double? width;
  final Widget? icon;
  final Color? borderColor;
  final Color? textColor;
  final double? borderRadius;
  final EdgeInsets? padding;
  
  @override
  Widget build(BuildContext context) {
    final responsiveHeight = height ?? ResponsiveUtils.responsiveSpacing(context: context, mobile: 48, tablet: 52, desktop: 56);
    final responsivePadding = padding ?? ResponsiveUtils.responsiveMarginSymmetric(context: context, horizontalMobile: 24, verticalMobile: 12);
    final responsiveBorderRadius = borderRadius ?? ResponsiveUtils.responsiveBorderRadius(context: context, mobile: 12, tablet: 14, desktop: 16);
    
    return SizedBox(
      width: isFullWidth ? double.infinity : width,
      height: responsiveHeight,
      child: OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: textColor ?? AppTheme.primaryColor,
          side: BorderSide(color: borderColor ?? AppTheme.primaryColor),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(responsiveBorderRadius),
          ),
          padding: responsivePadding,
        ),
        child: isLoading
            ? SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(textColor ?? AppTheme.primaryColor),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    icon!,
                    const SizedBox(width: 8),
                  ],
                  Text(
                    text,
                    style: TextStyle(
                      fontSize: ResponsiveUtils.responsiveFontSize(context: context, mobile: 16, tablet: 17, desktop: 18),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// Text button
class TextButtonCustom extends StatelessWidget {
  
  const TextButtonCustom({
    required this.text, super.key,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.textColor,
    this.padding,
  });
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Widget? icon;
  final Color? textColor;
  final EdgeInsets? padding;
  
  @override
  Widget build(BuildContext context) {
    final responsivePadding = padding ?? ResponsiveUtils.responsiveMarginSymmetric(context: context, verticalMobile: 8);
    
    return TextButton(
      onPressed: isLoading ? null : onPressed,
      style: TextButton.styleFrom(
        foregroundColor: textColor ?? AppTheme.primaryColor,
        padding: responsivePadding,
      ),
      child: isLoading
          ? SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(textColor ?? AppTheme.primaryColor),
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  icon!,
                  const SizedBox(width: 8),
                ],
                Text(
                  text,
                  style: TextStyle(
                    fontSize: ResponsiveUtils.responsiveFontSize(context: context, mobile: 16, tablet: 17, desktop: 18),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
    );
  }
}

// Icon button
class IconButtonCustom extends StatelessWidget {
  
  const IconButtonCustom({
    required this.icon, super.key,
    this.onPressed,
    this.iconColor,
    this.backgroundColor,
    this.size,
    this.iconSize,
    this.borderRadius,
    this.tooltip,
  });
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? iconColor;
  final Color? backgroundColor;
  final double? size;
  final double? iconSize;
  final double? borderRadius;
  final String? tooltip;
  
  @override
  Widget build(BuildContext context) {
    final responsiveSize = size ?? ResponsiveUtils.responsiveIconSize(context: context, mobile: 40, tablet: 44, desktop: 48);
    final responsiveIconSize = iconSize ?? ResponsiveUtils.responsiveIconSize(context: context, mobile: 20, tablet: 22, desktop: 24);
    final responsiveBorderRadius = borderRadius ?? ResponsiveUtils.responsiveBorderRadius(context: context, mobile: 8, tablet: 10, desktop: 12);
    
    Widget button = Container(
      width: responsiveSize,
      height: responsiveSize,
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.transparent,
        borderRadius: BorderRadius.circular(responsiveBorderRadius),
      ),
      child: Icon(
        icon,
        size: responsiveIconSize,
        color: iconColor ?? AppTheme.textPrimary,
      ),
    );
    
    if (onPressed != null) {
      button = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(responsiveBorderRadius),
          child: button,
        ),
      );
    }
    
    if (tooltip != null) {
      button = Tooltip(
        message: tooltip,
        child: button,
      );
    }
    
    return button;
  }
}

// Floating action button custom
class FloatingActionButtonCustom extends StatelessWidget {
  
  const FloatingActionButtonCustom({
    required this.icon, super.key,
    this.onPressed,
    this.tooltip,
    this.backgroundColor,
    this.iconColor,
    this.isExtended = false,
    this.text,
  });
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color? backgroundColor;
  final Color? iconColor;
  final bool isExtended;
  final String? text;
  
  @override
  Widget build(BuildContext context) {
    if (isExtended && text != null) {
      return FloatingActionButton.extended(
        onPressed: onPressed,
        tooltip: tooltip,
        backgroundColor: backgroundColor ?? AppTheme.primaryColor,
        foregroundColor: iconColor ?? AppTheme.textOnPrimary,
        icon: Icon(icon),
        label: Text(text!),
      );
    }
    
    return FloatingActionButton(
      onPressed: onPressed,
      tooltip: tooltip,
      backgroundColor: backgroundColor ?? AppTheme.primaryColor,
      foregroundColor: iconColor ?? AppTheme.textOnPrimary,
      child: Icon(icon),
    );
  }
}

// Button group
class ButtonGroup extends StatelessWidget {
  
  const ButtonGroup({
    required this.buttons, super.key,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.spacing = 16.0,
    this.isVertical = false,
  });
  final List<Widget> buttons;
  final MainAxisAlignment mainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;
  final double spacing;
  final bool isVertical;
  
  @override
  Widget build(BuildContext context) {
    if (isVertical) {
      return Column(
        mainAxisAlignment: mainAxisAlignment,
        crossAxisAlignment: crossAxisAlignment,
        children: _buildChildren(),
      );
    }
    
    return Row(
      mainAxisAlignment: mainAxisAlignment,
      crossAxisAlignment: crossAxisAlignment,
      children: _buildChildren(),
    );
  }
  
  List<Widget> _buildChildren() {
    final children = <Widget>[];
    
    for (var i = 0; i < buttons.length; i++) {
      children.add(buttons[i]);
      
      if (i < buttons.length - 1) {
        if (isVertical) {
          children.add(SizedBox(height: spacing));
        } else {
          children.add(SizedBox(width: spacing));
        }
      }
    }
    
    return children;
  }
}

// Toggle button group
class ToggleButtonGroup extends StatefulWidget {
  
  const ToggleButtonGroup({
    required this.options, super.key,
    this.onSelectionChanged,
    this.initialSelection,
    this.isFullWidth = false,
    this.selectedColor,
    this.unselectedColor,
    this.selectedTextColor,
    this.unselectedTextColor,
  });
  final List<String> options;
  final Function(int)? onSelectionChanged;
  final int? initialSelection;
  final bool isFullWidth;
  final Color? selectedColor;
  final Color? unselectedColor;
  final Color? selectedTextColor;
  final Color? unselectedTextColor;
  
  @override
  State<ToggleButtonGroup> createState() => _ToggleButtonGroupState();
}

class _ToggleButtonGroupState extends State<ToggleButtonGroup> {
  int? _selectedOption;
  
  @override
  void initState() {
    super.initState();
    _selectedOption = widget.initialSelection;
  }
  
  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(
        widget.options.length,
        (index) => Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() {
                _selectedOption = index;
              });
              widget.onSelectionChanged?.call(index);
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: _selectedOption == index
                    ? (widget.selectedColor ?? AppTheme.primaryColor)
                    : (widget.unselectedColor ?? Colors.transparent),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: widget.unselectedColor ?? AppTheme.borderColor,
                ),
              ),
              child: Text(
                widget.options[index],
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _selectedOption == index
                      ? (widget.selectedTextColor ?? AppTheme.textOnPrimary)
                      : (widget.unselectedTextColor ?? AppTheme.textPrimary),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
