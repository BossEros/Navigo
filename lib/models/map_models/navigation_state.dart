enum NavigationState {
  idle,           // Initial state, no destination selected
  placeSelected,  // A destination is selected, showing place details
  routePreview,   // Showing route options before starting navigation
  activeNavigation // Actively navigating
}