import 'package:flutter/material.dart';

class MarketDemandItem {
  final String name;
  final bool isTechnical;
  final int demandPercent;

  const MarketDemandItem({
    required this.name,
    required this.isTechnical,
    required this.demandPercent,
  });
}

class AnalysisMarketDemandCard extends StatelessWidget {
  final List<MarketDemandItem> topCriticalItems;

  const AnalysisMarketDemandCard({super.key, required this.topCriticalItems});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFBFDBFE), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFDBEAFE),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.trending_up,
                  color: Color(0xFF2563EB),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Market Demand Insight',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1C1E),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'How often these skills appear in job postings',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (topCriticalItems.isEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: const Text(
                "Great! You don't have any critical skill gaps.",
                style: TextStyle(fontSize: 14, color: Color(0xFF166534)),
              ),
            ),
          ] else ...[
            const SizedBox(height: 16),
            ...topCriticalItems.asMap().entries.map((entry) {
              final item = entry.value;
              final demand = item.demandPercent;
              final level = demand >= 75
                  ? 'High Demand'
                  : demand >= 60
                  ? 'Moderate Demand'
                  : 'Low Demand';
              return Padding(
                padding: EdgeInsets.only(
                  bottom: entry.key < topCriticalItems.length - 1 ? 12 : 0,
                ),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFBFDBFE).withValues(alpha: 0.6),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              item.name,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A1C1E),
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                          ),
                          Text(
                            '$demand%',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Text(
                            item.isTechnical ? '💻 Technical' : '🤝 Soft Skill',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          Text(
                            '• $level',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: demand >= 75
                                  ? const Color(0xFF15803D)
                                  : Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: demand / 100,
                          minHeight: 8,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF2563EB),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}
