import 'package:flutter/material.dart';

/// Curated visual template for one business category, used to seed a new
/// loyalty program's design during onboarding. `category` matches the
/// `business_category` enum added in supabase/migrations/0008_business_category.sql.
class BusinessTemplate {
  const BusinessTemplate({
    required this.category,
    required this.label,
    required this.icon,
    required this.primaryColor,
    required this.backgroundColor,
    required this.textColor,
    required this.punchColor,
    required this.punchIconType,
    required this.defaultPunchTerm,
    required this.defaultReward,
  });

  final String category;
  final String label;
  final IconData icon;
  final String primaryColor;
  final String backgroundColor;
  final String textColor;
  final String punchColor;
  final String punchIconType;
  final String defaultPunchTerm;
  final String defaultReward;
}

/// Twelve industry-tuned starting points. Owners can still fine-tune every
/// color and the punch icon afterwards in Program settings.
const businessTemplates = <BusinessTemplate>[
  BusinessTemplate(
    category: 'coffee_shop',
    label: 'Coffee Shop',
    icon: Icons.local_cafe,
    primaryColor: '#6B4F3A',
    backgroundColor: '#FFFDF9',
    textColor: '#2B211A',
    punchColor: '#6B4F3A',
    punchIconType: 'coffee',
    defaultPunchTerm: 'stamp',
    defaultReward: 'Free coffee',
  ),
  BusinessTemplate(
    category: 'restaurant',
    label: 'Restaurant',
    icon: Icons.restaurant,
    primaryColor: '#B23A2E',
    backgroundColor: '#FFFAF8',
    textColor: '#2A1712',
    punchColor: '#B23A2E',
    punchIconType: 'star',
    defaultPunchTerm: 'visit',
    defaultReward: 'Free appetizer',
  ),
  BusinessTemplate(
    category: 'bakery',
    label: 'Bakery & Pastry',
    icon: Icons.cake,
    primaryColor: '#C97B3D',
    backgroundColor: '#FFFBF4',
    textColor: '#2E2013',
    punchColor: '#C97B3D',
    punchIconType: 'gift',
    defaultPunchTerm: 'stamp',
    defaultReward: 'Free pastry',
  ),
  BusinessTemplate(
    category: 'bar_nightlife',
    label: 'Bar & Nightlife',
    icon: Icons.local_bar,
    primaryColor: '#7B2FE0',
    backgroundColor: '#FBF8FF',
    textColor: '#1E1530',
    punchColor: '#7B2FE0',
    punchIconType: 'star',
    defaultPunchTerm: 'visit',
    defaultReward: 'Free drink',
  ),
  BusinessTemplate(
    category: 'salon_spa',
    label: 'Salon & Spa',
    icon: Icons.content_cut,
    primaryColor: '#C2185B',
    backgroundColor: '#FFF7FA',
    textColor: '#2A1420',
    punchColor: '#C2185B',
    punchIconType: 'scissors',
    defaultPunchTerm: 'visit',
    defaultReward: 'Free service',
  ),
  BusinessTemplate(
    category: 'gym_fitness',
    label: 'Gym & Fitness',
    icon: Icons.fitness_center,
    primaryColor: '#2F6FED',
    backgroundColor: '#F5F8FF',
    textColor: '#131C2E',
    punchColor: '#2F6FED',
    punchIconType: 'dumbbell',
    defaultPunchTerm: 'visit',
    defaultReward: 'Free class',
  ),
  BusinessTemplate(
    category: 'retail_store',
    label: 'Retail Store',
    icon: Icons.storefront,
    primaryColor: '#16233F',
    backgroundColor: '#F7F8FA',
    textColor: '#16233F',
    punchColor: '#16233F',
    punchIconType: 'diamond',
    defaultPunchTerm: 'purchase',
    defaultReward: '20% off next order',
  ),
  BusinessTemplate(
    category: 'car_wash',
    label: 'Car Wash & Auto',
    icon: Icons.local_car_wash,
    primaryColor: '#0E7C86',
    backgroundColor: '#F3FBFC',
    textColor: '#0B2426',
    punchColor: '#0E7C86',
    punchIconType: 'car',
    defaultPunchTerm: 'wash',
    defaultReward: 'Free wash',
  ),
  BusinessTemplate(
    category: 'pet_services',
    label: 'Pet Services',
    icon: Icons.pets,
    primaryColor: '#E08A2B',
    backgroundColor: '#FFFAF3',
    textColor: '#2E200F',
    punchColor: '#E08A2B',
    punchIconType: 'paw',
    defaultPunchTerm: 'visit',
    defaultReward: 'Free grooming',
  ),
  BusinessTemplate(
    category: 'professional_services',
    label: 'Professional Services',
    icon: Icons.badge,
    primaryColor: '#334155',
    backgroundColor: '#F8FAFC',
    textColor: '#1A2230',
    punchColor: '#334155',
    punchIconType: 'circle',
    defaultPunchTerm: 'visit',
    defaultReward: 'Free consultation',
  ),
  BusinessTemplate(
    category: 'healthcare',
    label: 'Healthcare & Wellness',
    icon: Icons.local_hospital,
    primaryColor: '#2E9E4F',
    backgroundColor: '#F5FBF6',
    textColor: '#14261A',
    punchColor: '#2E9E4F',
    punchIconType: 'leaf',
    defaultPunchTerm: 'visit',
    defaultReward: 'Free session',
  ),
  BusinessTemplate(
    category: 'other',
    label: 'Other Business',
    icon: Icons.apps,
    primaryColor: '#2F6FED',
    backgroundColor: '#FFFFFF',
    textColor: '#16233F',
    punchColor: '#2F6FED',
    punchIconType: 'circle',
    defaultPunchTerm: 'punch',
    defaultReward: 'Free reward',
  ),
];
