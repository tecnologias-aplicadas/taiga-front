###
# This source code is licensed under the terms of the
# GNU Affero General Public License found in the LICENSE file in
# the root directory of this source tree.
#
# Copyright (c) 2021-present Kaleidos INC
###

taiga = @.taiga


REFRESH_DEBOUNCE_MS = 700

class EpicsDashboardController
    @.$inject = [
        "$routeParams",
        "tgErrorHandlingService",
        "tgLightboxFactory",
        "lightboxService",
        "$tgConfirm",
        "tgProjectService",
        "tgEpicsService",
        "tgAppMetaService",
        "$translate",
        "$scope",
        "$tgEvents",
        "$timeout"
    ]

    constructor: (@params, @errorHandlingService, @lightboxFactory, @lightboxService,
                  @confirm, @projectService, @epicsService, @appMetaService, @translate,
                  @scope, @events, @timeout) ->

        @.sectionName = "EPICS.SECTION_NAME"
        @.refreshTimeout = null

        taiga.defineImmutableProperty @, 'project', () => return @projectService.project
        taiga.defineImmutableProperty @, 'epics', () => return @epicsService.epics

        @appMetaService.setfn @._setMeta.bind(this)

    _setMeta: () ->
        return null if !@.project

        ctx = {
            projectName: @.project.get("name")
            projectDescription: @.project.get("description")
        }

        return {
            title: @translate.instant("EPICS.PAGE_TITLE", ctx)
            description: @translate.instant("EPICS.PAGE_DESCRIPTION", ctx)
        }

    loadInitialData: () ->
        @epicsService.clear()
        return @projectService.setProjectBySlug(@params.pslug)
            .then () =>
                if not @projectService.isEpicsDashboardEnabled()
                    return @errorHandlingService.notFound()
                if not @projectService.hasPermission("view_epics")
                    return @errorHandlingService.permissionDenied()

                @.initializeSubscription()
                return @epicsService.fetchEpics()

    # Eventos de épica (inclusive ligação de história) e de história recarregam a lista;
    # rajadas (operações em lote) viram uma só consulta após o intervalo
    initializeSubscription: () ->
        projectId = @projectService.project.get("id")

        @events.subscribe @scope, "changes.project.#{projectId}.epics", (message) =>
            @.scheduleRefresh()

        @events.subscribe @scope, "changes.project.#{projectId}.userstories", (message) =>
            @.scheduleRefresh()

        @scope.$on "$destroy", => @.cancelScheduledRefresh()

    scheduleRefresh: () ->
        @.cancelScheduledRefresh()
        @.refreshTimeout = @timeout (=>
            @.refreshTimeout = null
            @epicsService.refetchEpics().then =>
                @scope.$broadcast("epics:refreshed")
        ), REFRESH_DEBOUNCE_MS

    cancelScheduledRefresh: () ->
        return if not @.refreshTimeout
        @timeout.cancel(@.refreshTimeout)
        @.refreshTimeout = null

    canCreateEpics: () ->
        return @projectService.hasPermission("add_epic")

    onCreateEpic: () ->
        onCreateEpic =  () =>
            @lightboxService.closeAll()
            @confirm.notify("success")
            return # To prevent error https://docs.angularjs.org/error/$parse/isecdom?p0=onCreateEpic()

        @lightboxFactory.create('tg-create-epic', {
            "class": "lightbox lightbox-create-epic open"
            "on-create-epic": "onCreateEpic()"
        }, {
            "onCreateEpic": onCreateEpic.bind(this)
        })

angular.module("taigaEpics").controller("EpicsDashboardCtrl", EpicsDashboardController)
