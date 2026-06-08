import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../data/models/location_log.dart';
import '../../../data/models/photo_metadata.dart';
import '../../../data/models/match_status.dart';
import '../../../data/models/taken_time_source.dart';

class LociMapView extends StatefulWidget {
  final List<LocationLog> locationLogs;
  final List<PhotoMetadata> photos;
  final double? liveLatitude;
  final double? liveLongitude;

  const LociMapView({
    super.key,
    required this.locationLogs,
    required this.photos,
    this.liveLatitude,
    this.liveLongitude,
  });

  @override
  State<LociMapView> createState() => _LociMapViewState();
}

class _LociMapViewState extends State<LociMapView> {
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  @override
  void didUpdateWidget(covariant LociMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _buildMapData();
  }

  @override
  void initState() {
    super.initState();
    _buildMapData();
  }

  void _buildMapData() {
    _markers.clear();
    _polylines.clear();

    // 1. Build route polyline
    final List<LatLng> polylinePoints = [];
    for (final log in widget.locationLogs) {
      polylinePoints.add(LatLng(log.latitude, log.longitude));
    }

    if (polylinePoints.isNotEmpty) {
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('route'),
          points: polylinePoints,
          color: Colors.amber, // Gold theme color
          width: 5,
          geodesic: true,
        ),
      );
    }

    // 2. Build photo markers
    final matchedPhotos = widget.photos.where((p) => p.matchStatus == MatchStatus.matched);
    for (final photo in matchedPhotos) {
      if (photo.matchedLat != null && photo.matchedLng != null) {
        final timeStr = DateTime.fromMillisecondsSinceEpoch(photo.takenAt * 1000)
            .toLocal()
            .toString()
            .split(' ')[1]
            .substring(0, 5); // HH:mm format

        _markers.add(
          Marker(
            markerId: MarkerId(photo.assetId),
            position: LatLng(photo.matchedLat!, photo.matchedLng!),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
            infoWindow: InfoWindow(
              title: photo.assetTitle,
              snippet: '촬영 시간: $timeStr | 신뢰도: ${(photo.matchedConfidence! * 100).toStringAsFixed(0)}%',
            ),
          ),
        );
      }
    }

    // 3. Add live position marker if available
    if (widget.liveLatitude != null && widget.liveLongitude != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('live_location'),
          position: LatLng(widget.liveLatitude!, widget.liveLongitude!),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
          infoWindow: const InfoWindow(
            title: '현재 위치 (추적 중)',
          ),
        ),
      );
    }

    // Adjust camera bounds after rebuilding map data
    _fitBounds();
  }

  void _fitBounds() {
    if (_mapController == null) return;

    final List<LatLng> allPoints = [];

    // Add polyline points
    for (final log in widget.locationLogs) {
      allPoints.add(LatLng(log.latitude, log.longitude));
    }

    // Add marker positions
    for (final marker in _markers) {
      allPoints.add(marker.position);
    }

    if (allPoints.isEmpty) return;

    if (allPoints.length == 1) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(allPoints.first, 15.0),
      );
      return;
    }

    // Find bounding box
    double minLat = 90.0;
    double maxLat = -90.0;
    double minLng = 180.0;
    double maxLng = -180.0;

    for (final point in allPoints) {
      minLat = math.min(minLat, point.latitude);
      maxLat = math.max(maxLat, point.latitude);
      minLng = math.min(minLng, point.longitude);
      maxLng = math.max(maxLng, point.longitude);
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 50.0), // 50dp padding
    );
  }

  @override
  Widget build(BuildContext context) {
    // Determine initial camera position (fallback to Seoul)
    LatLng initialCenter = const LatLng(37.5665, 126.9780);
    if (widget.locationLogs.isNotEmpty) {
      initialCenter = LatLng(widget.locationLogs.first.latitude, widget.locationLogs.first.longitude);
    } else if (widget.photos.isNotEmpty) {
      final matched = widget.photos.firstWhere(
        (p) => p.matchStatus == MatchStatus.matched && p.matchedLat != null,
        orElse: () => PhotoMetadata(
          assetId: '',
          journalDate: '',
          assetTitle: '',
          relativePath: '',
          takenAt: 0,
          takenTimeSource: TakenTimeSource.assetCreateTime, // Fallback
          matchStatus: MatchStatus.unmatchedNoLocation,
        ),
      );
      if (matched.matchedLat != null) {
        initialCenter = LatLng(matched.matchedLat!, matched.matchedLng!);
      }
    } else if (widget.liveLatitude != null && widget.liveLongitude != null) {
      initialCenter = LatLng(widget.liveLatitude!, widget.liveLongitude!);
    }

    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: initialCenter,
        zoom: 14.0,
      ),
      markers: _markers,
      polylines: _polylines,
      myLocationEnabled: false,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: true,
      mapToolbarEnabled: false,
      onMapCreated: (GoogleMapController controller) {
        _mapController = controller;
        // Apply M3 map styling if needed in future, otherwise default is clean
        _fitBounds();
      },
    );
  }
}
