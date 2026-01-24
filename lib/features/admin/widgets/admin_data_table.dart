import 'dart:async';
import 'package:flutter/material.dart';
import 'package:eduverse/utils/app_theme.dart';

/// Paginated Data Table Widget for Admin Module
/// Supports lazy loading, search, and actions
class AdminDataTable extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  final List<AdminTableColumn> columns;
  final bool isLoading;
  final bool hasMore;
  final VoidCallback? onLoadMore;
  final String? emptyMessage;
  final Widget Function(Map<String, dynamic>)? actionsBuilder;
  final Function(Map<String, dynamic>)? onRowTap;

  const AdminDataTable({
    super.key,
    required this.data,
    required this.columns,
    this.isLoading = false,
    this.hasMore = false,
    this.onLoadMore,
    this.emptyMessage,
    this.actionsBuilder,
    this.onRowTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    if (data.isEmpty && !isLoading) {
      return _buildEmptyState(isDark);
    }

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.getCardColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : Colors.grey.shade200,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: isMobile ? _buildMobileList(isDark) : _buildDesktopTable(isDark),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : Colors.grey.shade200,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.inbox_rounded,
            size: 64,
            color: isDark ? AppTheme.darkTextTertiary : Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            emptyMessage ?? 'No data available',
            style: TextStyle(
              color: isDark
                  ? AppTheme.darkTextSecondary
                  : AppTheme.textSecondary,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  /// Desktop table layout
  Widget _buildDesktopTable(bool isDark) {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDark
                ? AppTheme.darkBackground.withOpacity(0.5)
                : Colors.grey.shade50,
            border: Border(
              bottom: BorderSide(
                color: isDark ? AppTheme.darkBorder : Colors.grey.shade200,
              ),
            ),
          ),
          child: Row(
            children: [
              ...columns.map(
                (col) => Expanded(
                  flex: col.flex,
                  child: Text(
                    col.title,
                    style: TextStyle(
                      color: isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              if (actionsBuilder != null)
                const SizedBox(
                  width: 150,
                  child: Text(
                    'Actions',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
        // Data rows
        Expanded(
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is ScrollEndNotification &&
                  notification.metrics.extentAfter < 200 &&
                  hasMore &&
                  !isLoading) {
                onLoadMore?.call();
              }
              return false;
            },
            child: ListView.builder(
              itemCount: data.length + (isLoading || hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= data.length) {
                  return _buildLoadingRow(isDark);
                }

                final item = data[index];
                return _buildTableRow(item, isDark, index);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTableRow(Map<String, dynamic> item, bool isDark, int index) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onRowTap != null ? () => onRowTap!(item) : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: index.isEven
                ? Colors.transparent
                : (isDark
                      ? AppTheme.darkBackground.withOpacity(0.3)
                      : Colors.grey.shade50.withOpacity(0.5)),
            border: Border(
              bottom: BorderSide(
                color: isDark
                    ? AppTheme.darkBorder.withOpacity(0.5)
                    : Colors.grey.shade100,
              ),
            ),
          ),
          child: Row(
            children: [
              ...columns.map(
                (col) => Expanded(
                  flex: col.flex,
                  child: col.builder != null
                      ? col.builder!(item)
                      : Text(
                          item[col.field]?.toString() ?? '-',
                          style: TextStyle(
                            color: isDark
                                ? AppTheme.darkTextPrimary
                                : AppTheme.textPrimary,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                ),
              ),
              if (actionsBuilder != null)
                SizedBox(
                  width: 150,
                  child: Center(child: actionsBuilder!(item)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Mobile list layout
  Widget _buildMobileList(bool isDark) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollEndNotification &&
            notification.metrics.extentAfter < 200 &&
            hasMore &&
            !isLoading) {
          onLoadMore?.call();
        }
        return false;
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: data.length + (isLoading || hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= data.length) {
            return _buildLoadingCard(isDark);
          }

          final item = data[index];
          return _buildMobileCard(item, isDark);
        },
      ),
    );
  }

  Widget _buildMobileCard(Map<String, dynamic> item, bool isDark) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: isDark ? AppTheme.darkCard : Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? AppTheme.darkBorder : Colors.grey.shade200,
        ),
      ),
      child: InkWell(
        onTap: onRowTap != null ? () => onRowTap!(item) : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...columns.map(
                (col) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 100,
                        child: Text(
                          col.title,
                          style: TextStyle(
                            color: isDark
                                ? AppTheme.darkTextSecondary
                                : AppTheme.textSecondary,
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Expanded(
                        child: col.builder != null
                            ? col.builder!(item)
                            : Text(
                                item[col.field]?.toString() ?? '-',
                                style: TextStyle(
                                  color: isDark
                                      ? AppTheme.darkTextPrimary
                                      : AppTheme.textPrimary,
                                  fontSize: 14,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
              if (actionsBuilder != null) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [actionsBuilder!(item)],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingRow(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: isDark ? AppTheme.darkPrimary : AppTheme.primaryColor,
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingCard(bool isDark) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: isDark ? AppTheme.darkCard : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: isDark ? AppTheme.darkPrimary : AppTheme.primaryColor,
            ),
          ),
        ),
      ),
    );
  }
}

/// Column definition for AdminDataTable
class AdminTableColumn {
  final String title;
  final String field;
  final int flex;
  final Widget Function(Map<String, dynamic>)? builder;

  const AdminTableColumn({
    required this.title,
    required this.field,
    this.flex = 1,
    this.builder,
  });
}

/// Search bar for data tables
class AdminSearchBar extends StatefulWidget {
  final String hintText;
  final Function(String) onSearch;
  final String? initialValue;

  const AdminSearchBar({
    super.key,
    this.hintText = 'Search...',
    required this.onSearch,
    this.initialValue,
  });

  @override
  State<AdminSearchBar> createState() => _AdminSearchBarState();
}

class _AdminSearchBarState extends State<AdminSearchBar> {
  late TextEditingController _controller;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      widget.onSearch(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : Colors.grey.shade200,
        ),
      ),
      child: TextField(
        controller: _controller,
        onChanged: _onSearchChanged,
        style: TextStyle(
          color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
        ),
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: TextStyle(
            color: isDark ? AppTheme.darkTextTertiary : AppTheme.textSecondary,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
          ),
          suffixIcon: _controller.text.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.clear_rounded,
                    color: isDark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.textSecondary,
                  ),
                  onPressed: () {
                    _controller.clear();
                    widget.onSearch('');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }
}

/// Filter chip widget
class AdminFilterChips extends StatelessWidget {
  final String label;
  final List<String> options;
  final String selectedValue;
  final Function(String) onSelected;

  const AdminFilterChips({
    super.key,
    required this.label,
    required this.options,
    required this.selectedValue,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);

    return Row(
      children: [
        Text(
          '$label:',
          style: TextStyle(
            color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
        ),
        const SizedBox(width: 8),
        ...options.map((option) {
          final isSelected =
              selectedValue.toLowerCase() == option.toLowerCase();
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(
                option[0].toUpperCase() + option.substring(1),
                style: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : (isDark
                            ? AppTheme.darkTextPrimary
                            : AppTheme.textPrimary),
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
              selected: isSelected,
              onSelected: (_) => onSelected(option),
              selectedColor: isDark
                  ? AppTheme.darkPrimary
                  : AppTheme.primaryColor,
              backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
              side: BorderSide(
                color: isSelected
                    ? Colors.transparent
                    : (isDark ? AppTheme.darkBorder : Colors.grey.shade300),
              ),
              showCheckmark: false,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            ),
          );
        }),
      ],
    );
  }
}
