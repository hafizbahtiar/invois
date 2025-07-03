import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:invois/configs/routes/routes_name.dart';
import 'package:invois/features/shared/widgets/simple_header_section.dart';

class QuickActionsSection extends StatelessWidget {
  const QuickActionsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SimpleHeaderSection(
              title: 'Quick Actions',
              variant: SimpleHeaderVariant.primary,
            ),
            _buildActionGrid(context),
          ],
        )
        .animate()
        .fadeIn(delay: 200.ms, duration: 600.ms)
        .slideY(begin: 0.3, end: 0);
  }

  Widget _buildActionGrid(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 2,
      mainAxisSpacing: 2,
      childAspectRatio: 1.1,
      children: [
        _buildActionCard(
          context,
          icon: Icons.business,
          title: 'Business List',
          subtitle: 'Manage your business',
          color: Colors.blue,
          onTap: () => Navigator.pushNamed(context, RoutesName.businessList),
        ),
        _buildActionCard(
          context,
          icon: Icons.draw,
          title: 'Signature List',
          subtitle: 'Manage your signature',
          color: Colors.green,
          onTap: () => Navigator.pushNamed(context, RoutesName.signatureList),
        ),
        _buildActionCard(
          context,
          icon: Icons.receipt_long,
          title: 'Tax List',
          subtitle: 'Manage your tax',
          color: Colors.red,
          onTap: () => Navigator.pushNamed(context, RoutesName.taxList),
        ),
        _buildActionCard(
          context,
          icon: Icons.description,
          title: 'Term List',
          subtitle: 'Manage your term',
          color: Colors.purple,
          onTap: () => Navigator.pushNamed(context, RoutesName.termList),
        ),
        _buildActionCard(
          context,
          icon: Icons.group,
          title: 'Client List',
          subtitle: 'Manage your client',
          color: Colors.orange,
          onTap: () => Navigator.pushNamed(context, RoutesName.clientList),
        ),
        _buildActionCard(
          context,
          icon: Icons.receipt_long,
          title: 'Invoice List',
          subtitle: 'Manage your invoice',
          color: Colors.pink,
          onTap: () => Navigator.pushNamed(context, RoutesName.invoiceList),
        ),
      ],
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 6,
      shadowColor: color.withValues(alpha: 0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withValues(alpha: 0.1),
                color.withValues(alpha: 0.05),
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 24, color: color),
              ),
              const Spacer(),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
