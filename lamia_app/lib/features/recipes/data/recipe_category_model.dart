import 'package:flutter/material.dart';

/// Representation of a Filipino recipe category in La Mia.
class RecipeCategoryModel {
  const RecipeCategoryModel({
    required this.id,
    required this.name,
    required this.tagline,
    required this.icon,
    this.badgeColor,
  });

  final String id;
  final String name;
  final String tagline;
  final IconData icon;
  final Color? badgeColor;

  static const List<RecipeCategoryModel> defaultCategories = [
    RecipeCategoryModel(
      id: 'almusal',
      name: 'Almusal',
      tagline: 'Filipino Breakfast & Tapsilog',
      icon: Icons.wb_sunny_outlined,
    ),
    RecipeCategoryModel(
      id: 'ulam',
      name: 'Ulam',
      tagline: 'Main Course & Stews',
      icon: Icons.restaurant_outlined,
    ),
    RecipeCategoryModel(
      id: 'sabaw',
      name: 'Sabaw',
      tagline: 'Warm Soups & Broths',
      icon: Icons.soup_kitchen_outlined,
    ),
    RecipeCategoryModel(
      id: 'merienda',
      name: 'Merienda',
      tagline: 'Afternoon Snacks & Bites',
      icon: Icons.bakery_dining_outlined,
    ),
    RecipeCategoryModel(
      id: 'panghimagas',
      name: 'Panghimagas',
      tagline: 'Desserts & Sweets',
      icon: Icons.icecream_outlined,
    ),
    RecipeCategoryModel(
      id: 'gulay',
      name: 'Gulay',
      tagline: 'Vegetable Delights',
      icon: Icons.eco_outlined,
    ),
    RecipeCategoryModel(
      id: 'inihaw',
      name: 'Inihaw',
      tagline: 'Grilled & Charcoal Smoked',
      icon: Icons.local_fire_department_outlined,
    ),
    RecipeCategoryModel(
      id: 'lamang_dagat',
      name: 'Lamang Dagat',
      tagline: 'Seafood Classics',
      icon: Icons.set_meal_outlined,
    ),
  ];
}
