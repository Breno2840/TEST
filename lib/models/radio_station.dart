class RadioStation {
  final String name;
  final String streamUrl;
  final String? artUrl;

  RadioStation({
    required this.name,
    required this.streamUrl,
    this.artUrl,
  });

  factory RadioStation.fromJson(Map<String, dynamic> json) {
    String streamUrl = json['streamUrl'] ?? json['url'] ?? json['stream'] ?? '';
    streamUrl = streamUrl.trim();
    
    return RadioStation(
      name: json['name'] ?? json['title'] ?? 'Unknown Station',
      streamUrl: streamUrl,
      artUrl: json['artUrl'] ?? json['image'] ?? json['logo'],
    );
  }
}