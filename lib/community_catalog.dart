import 'package:flutter/material.dart';

/// Familiar category names remain unchanged, so existing posts still filter
/// correctly after the catalog expands. No empty or fake community activity is
/// seeded into the server.
const categories = <String>[
  'All',
  'Community & volunteering',
  'Events & meetups',
  'Technology',
  'Learning',
  'Career',
  'Home & repairs',
  'Sports',
  'Creative',
  'Local knowledge',
  'Fitness & outdoors',
  'Food & cooking',
  'Travel & transport',
  'Business & startups',
  'Gardening & nature',
  'Pets & animals',
  'Family & parenting',
  'Languages & culture',
  'Accessibility',
  'Health & wellbeing',
  'Finance & paperwork',
  'Neighborhood safety',
  'Music & entertainment',
  'Other',
];

class CommunityTemplate {
  const CommunityTemplate(this.name, this.category, this.description, this.icon);
  final String name;
  final String category;
  final String description;
  final IconData icon;
}

/// Starter IDEAS, never fictional active groups. A human chooses to create
/// one and becomes its accountable owner before it appears in discovery.
const communityTemplates = <CommunityTemplate>[
  CommunityTemplate('Neighborhood Helpers', 'Community & volunteering',
    'Exchange practical help with people in your area.', Icons.volunteer_activism_outlined),
  CommunityTemplate('Study Buddies', 'Learning',
    'Share study plans, revision tips and peer learning.', Icons.school_outlined),
  CommunityTemplate('Tech Fixers', 'Technology',
    'Help each other understand devices and common tech issues.', Icons.devices_outlined),
  CommunityTemplate('Career & Skills', 'Career',
    'Peer guidance for job searches, CVs and professional skills.', Icons.work_outline),
  CommunityTemplate('Walking & Fitness', 'Fitness & outdoors',
    'Plan walks and encourage healthy everyday routines.', Icons.directions_walk_outlined),
  CommunityTemplate('Gardeners Network', 'Gardening & nature',
    'Share planting ideas, cuttings and neighborhood gardening tips.', Icons.yard_outlined),
  CommunityTemplate('Language Exchange', 'Languages & culture',
    'Practice languages and learn about other cultures.', Icons.translate_outlined),
  CommunityTemplate('Creative Makers', 'Creative',
    'Connect around design, crafts, writing and DIY projects.', Icons.palette_outlined),
  CommunityTemplate('Local Events', 'Events & meetups',
    'Discover community events and plan safe public meetups.', Icons.event_outlined),
  CommunityTemplate('Pet Care Circle', 'Pets & animals',
    'Exchange everyday pet-care information and local tips.', Icons.pets_outlined),
  CommunityTemplate('Food & Cooking', 'Food & cooking',
    'Swap recipes, practical kitchen ideas and cooking skills.', Icons.restaurant_outlined),
  CommunityTemplate('Volunteer Projects', 'Community & volunteering',
    'Coordinate responsible, voluntary neighborhood projects.', Icons.handshake_outlined),
];
