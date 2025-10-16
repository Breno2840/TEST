class RadioStation {
  final String name;
  final String streamUrl;
  final String? artUrl;
  final String? location; // NOVO!

  RadioStation({
    required this.name,
    required this.streamUrl,
    this.artUrl,
    this.location, // NOVO!
  });

  factory RadioStation.fromJson(Map<String, dynamic> json) {
    String streamUrl = json['streamUrl'] ?? json['url'] ?? json['stream'] ?? '';
    streamUrl = streamUrl.trim();
    
    return RadioStation(
      name: json['name'] ?? json['title'] ?? 'Unknown Station',
      streamUrl: streamUrl,
      artUrl: json['artUrl'] ?? json['image'] ?? json['logo'],
      location: json['location'] ?? json['city'] ?? json['state'] ?? json['country'], // NOVO!
    );
  }
}