class NotificationPreferenceModel {
  const NotificationPreferenceModel({
    required this.likes,
    required this.comments,
    required this.followers,
    required this.followingNewRecipes,
    required this.mealReminders,
    required this.dailySuggestions,
  });

  final bool likes;
  final bool comments;
  final bool followers;
  final bool followingNewRecipes;
  final bool mealReminders;
  final bool dailySuggestions;

  factory NotificationPreferenceModel.defaults() {
    return const NotificationPreferenceModel(
      likes: true,
      comments: true,
      followers: true,
      followingNewRecipes: true,
      mealReminders: true,
      dailySuggestions: true,
    );
  }

  factory NotificationPreferenceModel.fromMap(Map<String, dynamic>? data) {
    if (data == null) return NotificationPreferenceModel.defaults();
    return NotificationPreferenceModel(
      likes: data['likes'] as bool? ?? true,
      comments: data['comments'] as bool? ?? true,
      followers: data['followers'] as bool? ?? true,
      followingNewRecipes: data['followingNewRecipes'] as bool? ?? true,
      mealReminders: data['mealReminders'] as bool? ?? true,
      dailySuggestions: data['dailySuggestions'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'likes': likes,
      'comments': comments,
      'followers': followers,
      'followingNewRecipes': followingNewRecipes,
      'mealReminders': mealReminders,
      'dailySuggestions': dailySuggestions,
    };
  }

  NotificationPreferenceModel copyWith({
    bool? likes,
    bool? comments,
    bool? followers,
    bool? followingNewRecipes,
    bool? mealReminders,
    bool? dailySuggestions,
  }) {
    return NotificationPreferenceModel(
      likes: likes ?? this.likes,
      comments: comments ?? this.comments,
      followers: followers ?? this.followers,
      followingNewRecipes: followingNewRecipes ?? this.followingNewRecipes,
      mealReminders: mealReminders ?? this.mealReminders,
      dailySuggestions: dailySuggestions ?? this.dailySuggestions,
    );
  }
}
