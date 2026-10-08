TicketDependenciesDirective = (lightboxService) ->
  link = (scope, el, attrs, ctrl) ->
    scope.openModal = ->
      lightboxEl = el.find(".lightbox-add-dependency")
      closeFn = -> lightboxService.close(lightboxEl)
      ctrl.openDependenciesModal(closeFn)
      lightboxService.open(lightboxEl, -> ctrl.closeModal())

  return {
    scope: true
    bindToController:
      item: "="
      project: "="
      itemType: "=?"
      shared: "="
    controller: "DependenciesListController"
    controllerAs: "vm"
    templateUrl: "components/dependencies-list/ticket-dependencies.html"
    link: link
  }

TicketDependenciesDirective.$inject = ["lightboxService"]

angular.module("taigaComponents")
  .directive("tgTicketDependencies", TicketDependenciesDirective)