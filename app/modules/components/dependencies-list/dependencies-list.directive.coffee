angular.module("taigaComponents")
  .directive "tgDependenciesList", ->
    restrict: "E"
    scope: {}
    bindToController:
      item: "="
      project: "="
      shared: "="
    controller: "DependenciesListController"
    controllerAs: "vm"
    templateUrl: "components/dependencies-list/dependencies-list.html"
