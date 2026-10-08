###
# This source code is licensed under the terms of the
# GNU Affero General Public License found in the LICENSE file in
# the root directory of this source tree.
#
# Copyright (c) 2021-present Kaleidos INC
###

taiga = @.taiga

mixOf = @.taiga.mixOf
toString = @.taiga.toString
joinStr = @.taiga.joinStr
groupBy = @.taiga.groupBy
bindOnce = @.taiga.bindOnce
bindMethods = @.taiga.bindMethods

module = angular.module("taigaEpics")

#############################################################################
## Epic Detail Controller
#############################################################################

class EpicDetailController extends mixOf(taiga.Controller, taiga.PageMixin, taiga.DetailEventsMixin)
    @.$inject = [
        "$scope",
        "$rootScope",
        "$tgRepo",
        "$tgConfirm",
        "$tgResources",
        "tgResources"
        "$routeParams",
        "$q",
        "$tgLocation",
        "$log",
        "tgAppMetaService",
        "$tgAnalytics",
        "$tgNavUrls",
        "$translate",
        "$tgQueueModelTransformation",
        "tgErrorHandlingService",
        "tgProjectService",
        "tgAttachmentsFullService",
        "$tgEvents",
        "tgEditingTracker"
    ]

    constructor: (@scope, @rootscope, @repo, @confirm, @rs, @rs2, @params, @q, @location,
                  @log, @appMetaService, @analytics, @navUrls, @translate, @modelTransform, @errorHandlingService, @projectService, @attachmentsFullService,
                  @events, @editingTracker) ->
        bindMethods(@)

        @scope.epicRef = @params.epicref
        @scope.sectionName = @translate.instant("EPIC.SECTION_NAME")
        @scope.attachmentsReady = false
        @scope.$on "attachments:loaded", () =>
            @scope.attachmentsReady = true

        @.project = @projectService.project.toJS()
        @.canModify =  @.project.my_permissions.includes("modify_epic")

        @.initializeEventHandlers()

        promise = @.loadInitialData()

        # On Success
        promise.then =>
            @._setMeta()
            @._inicializeDates()
            @._formatDate()
            @.initializeOnDeleteGoToUrl()

        # On Error
        promise.then null, @.onInitialDataError.bind(@)

    _setMeta: ->
        title = @translate.instant("EPIC.PAGE_TITLE", {
            epicRef: "##{@scope.epic.ref}"
            epicSubject: @scope.epic.subject
            projectName: @scope.project.name
        })
        description = @translate.instant("EPIC.PAGE_DESCRIPTION", {
            epicStatus: @scope.statusById[@scope.epic.status]?.name or "--"
            epicDescription: angular.element(@scope.epic.description_html or "").text()
        })
        @appMetaService.setAll(title, description)

    _inicializeDates: ->
        # garante que o objeto Date volte à meia-noite (00:00:00.000)
        toMidnight = (input) ->
            d = if input? then new Date(input) else new Date()
            d.setHours 0, 0, 0, 0
            d

        {epic} = @scope

        @startDate              = toMidnight epic?.start_date
        @expectedCompletionDate = toMidnight epic?.expected_completion_date
        @completionDate         = toMidnight epic?.completion_date  if epic?.completion_date?


    _formatDate: () ->
        @.startDate = if @scope.epic.start_date then new Date(@scope.epic.start_date + "T00:00:00") else null
        @.expectedCompletionDate = if @scope.epic.expected_completion_date then new Date(@scope.epic.expected_completion_date + "T00:00:00") else null
        @.completionDate = if @scope.epic.completion_date then new Date(@scope.epic.completion_date + "T00:00:00") else null
        @completionPercentDone = @scope.epic?.completion_percent_done + "%"
        @completionPercentProgress = @scope.epic?.completion_percent_progress + "%"
        @.updateDateConstraints()

    loadAttachments: ->
        @attachmentsFullService.loadAttachments('epic', @scope.epicId, @scope.projectId)

    initializeEventHandlers: ->
        @scope.$on "attachment:create", =>
            @analytics.trackEvent("attachment", "create", "create attachment on epic", 1)

        @scope.$on "comment:new", =>
            @.loadEpic()

        @scope.$on "custom-attributes-values:edit", =>
            @rootscope.$broadcast("object:updated")

        # Ouvintes no scope da tela (o raiz faz $broadcast, que chega aqui): morrem
        # com a tela em vez de sobreviver à troca de rota e recarregar sem epicref
        @scope.$on "object:updated", =>
            @loadEpic()

        # quando uma US for adicionada à epic
        @scope.$on "epic:userstory:created", (event, epicId) =>
            if epicId == @scope.epicId
                @.loadEpic()

    initializeSubscription: ->
        @.subscribeDetailEvents [
            {
                # A própria épica (inclusive ligar/desligar história chega como change dela):
                # recarrega a lista de histórias, a épica e a atividade; exclusão não reconsulta
                routingKey: "changes.project.#{@scope.projectId}.epics"
                matches: (message) => message.type != "delete" and @.eventTargets(message, @scope.epicId)
                reload: =>
                    @.loadRelatedUserstories()
                    @rootscope.$broadcast("object:updated")
                    @scope.$broadcast("custom-attributes-values:reload")
            },
            {
                # Histórias da épica: só a lista; o percentual da épica chega pelo evento dela
                routingKey: "changes.project.#{@scope.projectId}.userstories"
                matches: (message) => @.eventTargets(message, @._relatedUserstoryIds())
                reload: => @.loadRelatedUserstories()
            }
        ]

    _relatedUserstoryIds: ->
        return [] if not @scope.userstories
        return @scope.userstories.map((us) -> us.get("id")).toArray()

    initializeOnDeleteGoToUrl: ->
       ctx = {project: @scope.project.slug}
       @scope.onDeleteGoToUrl = @navUrls.resolve("project-epics", ctx)

    loadProject: ->
        project = @projectService.project.toJS()

        @scope.projectId = project.id
        @scope.project = project
        @scope.immutableProject = @projectService.project
        @scope.$emit('project:loaded', project)
        @scope.statusList = project.epic_statuses
        @scope.statusById = groupBy(project.epic_statuses, (x) -> x.id)
        return project

    loadEpic: ->
        return @rs.epics.getByRef(@scope.projectId, @params.epicref).then (epic) =>
            @scope.epic = epic
            @scope.immutableEpic = Immutable.fromJS(epic._attrs)
            @scope.epicId = epic.id
            @scope.commentModel = epic

            @_formatDate()
            @.loadAttachments()

            @modelTransform.setObject(@scope, 'epic')

            if @scope.epic.neighbors.previous?.ref?
                ctx = {
                    project: @scope.project.slug
                    ref: @scope.epic.neighbors.previous.ref
                }
                @scope.previousUrl = @navUrls.resolve("project-epics-detail", ctx)

            if @scope.epic.neighbors.next?.ref?
                ctx = {
                    project: @scope.project.slug
                    ref: @scope.epic.neighbors.next.ref
                }
                @scope.nextUrl = @navUrls.resolve("project-epics-detail", ctx)

    loadRelatedUserstories: ->
        return @rs2.userstories.listInEpic(@scope.epicId).then (data) =>
            @scope.userstories = data
            return data

    loadUserstories: ->
        return @.loadRelatedUserstories().then => @.loadEpic()

    loadInitialData: ->
        project = @.loadProject()

        @.fillUsersAndRoles(project.members, project.roles)
        @.initializeSubscription()
        @.loadEpic().then(=> @.loadUserstories())

    ###
    # Note: This methods (onUpvote() and onDownvote()) are related to tg-vote-button.
    #       See app/modules/components/vote-button for more info
    ###
    onUpvote: ->
        onSuccess = =>
            @.loadEpic()
            @rootscope.$broadcast("object:updated")
        onError = =>
            @confirm.notify("error")

        return @rs.epics.upvote(@scope.epicId).then(onSuccess, onError)

    onDownvote: ->
        onSuccess = =>
            @.loadEpic()
            @rootscope.$broadcast("object:updated")
        onError = =>
            @confirm.notify("error")

        return @rs.epics.downvote(@scope.epicId).then(onSuccess, onError)

    updateEpicDate: (epic, dateTypeIndex, date) ->
        return if date == undefined

        dateTypes = [
            "start_date",
            "expected_completion_date",
            "completion_date",
        ]

        data = {
            "#{dateTypes[dateTypeIndex]}": date,
            version: epic.get('version')
        }

        return @rs2.epics.patch(epic.get("id"), data)

    _isInvalidDate: (date) ->
        return !date or isNaN(date.getTime())

    _resetStartDate: ->
        @.startDate = if @scope.epic?.start_date then new Date(@scope.epic.start_date + "T00:00:00") else null

    _resetExpectedCompletionDate: ->
        @.expectedCompletionDate = if @scope.epic?.expected_completion_date then new Date(@scope.epic.expected_completion_date + "T00:00:00") else null

    _isStartDateValid: ->
        return false if @._isInvalidDate(@.startDate)
        return false if @.startDateMin and @.startDate < @.startDateMin
        return false if @.calculatedStartDateMax and @.startDate > @.calculatedStartDateMax
        return true

    _isExpectedCompletionDateValid: ->
        return false if @._isInvalidDate(@.expectedCompletionDate)
        return false if @.calculatedMinAllowedDate and @.expectedCompletionDate < @.calculatedMinAllowedDate
        return true

    _notifyError: (response) ->
        data = response?.data or {}
        rawCode = data.code
        rawCode = rawCode[0] if Array.isArray(rawCode)
        if rawCode
            @confirm.notify('error', @translate.instant("ERRORS.#{rawCode.toUpperCase()}"))
        else
            @confirm.notify('error')

    updateStartDate: ->
        return unless @._isStartDateValid()

        @.startDateError = ''
        @.startDateBorderAlert = ''

        @updateEpicDate(@scope.immutableEpic, 0, @.startDate.toISOString().split('T')[0])
            .then (updated) =>
                @.expectedCompletionDateError = ''
                @.expectedCompletionDateBorderAlert = ''
                @.expectedCompletioDateBorderAlert = ''
                @confirm.notify('success')
                @replaceEpic?(updated)
                @rootscope.$broadcast("object:updated")
            .catch (response) =>
                @._resetStartDate()
                @updateDateConstraints()
                @._notifyError(response)

    blurStartDate: ->
        if @._isStartDateValid()
            saved = if @scope.epic?.start_date then new Date(@scope.epic.start_date + "T00:00:00") else null
            @.updateStartDate() if !saved or @.startDate?.getTime() isnt saved.getTime()
        else
            @._resetStartDate()
            @.startDateError = ''
            @.startDateBorderAlert = ''
            @confirm.notify('error', @translate.instant('ERRORS.START_DATE_EXCEEDS_END_DATE'))

    updateExpectedCompletionDate: ->
        return unless @._isExpectedCompletionDateValid()

        @.expectedCompletionDateError = ''
        @.expectedCompletionDateBorderAlert = ''
        @.expectedCompletioDateBorderAlert = ''

        @updateEpicDate(@scope.immutableEpic, 1, @.expectedCompletionDate.toISOString().split('T')[0])
            .then (updated) =>
                @.startDateError = ''
                @.startDateBorderAlert = ''
                @confirm.notify('success')
                @replaceEpic?(updated)
                @rootscope.$broadcast("object:updated")
            .catch (response) =>
                @._resetExpectedCompletionDate()
                @updateDateConstraints()
                @._notifyError(response)

    blurExpectedCompletionDate: ->
        if @._isExpectedCompletionDateValid()
            saved = if @scope.epic?.expected_completion_date then new Date(@scope.epic.expected_completion_date + "T00:00:00") else null
            @.updateExpectedCompletionDate() if !saved or @.expectedCompletionDate?.getTime() isnt saved.getTime()
        else
            @._resetExpectedCompletionDate()
            @.expectedCompletionDateError = ''
            @.expectedCompletionDateBorderAlert = ''
            @.expectedCompletioDateBorderAlert = ''
            @confirm.notify('error', @translate.instant('ERRORS.END_DATE_BEFORE_START_DATE'))


    ###
    # Note: This methods (onWatch() and onUnwatch()) are related to tg-watch-button.
    #       See app/modules/components/watch-button for more info
    ###
    onWatch: ->
        onSuccess = =>
            @.loadEpic()
            @rootscope.$broadcast("object:updated")
        onError = =>
            @confirm.notify("error")

        return @rs.epics.watch(@scope.epicId).then(onSuccess, onError)

    onUnwatch: ->
        onSuccess = =>
            @.loadEpic()
            @rootscope.$broadcast("object:updated")
        onError = =>
            @confirm.notify("error")

        return @rs.epics.unwatch(@scope.epicId).then(onSuccess, onError)

    onSelectColor: (color) ->
        onSelectColorSuccess = () =>
            @rootscope.$broadcast("object:updated")
            @confirm.notify('success')

        onSelectColorError = () =>
            @confirm.notify('error')

        transform = @modelTransform.save (epic) ->
            epic.color = color
            return epic

        return transform.then(onSelectColorSuccess, onSelectColorError)

    updateDateConstraints: ->
        limitDate = null

        if @.completionDate and @.expectedCompletionDate
            limitDate = if @.completionDate < @.expectedCompletionDate then @.completionDate else @.expectedCompletionDate
        else if @.completionDate
            limitDate = @.completionDate
        else if @.expectedCompletionDate
            limitDate = @.expectedCompletionDate

        # startDate pode ser igual à data limite (mesmo dia permitido)
        @.calculatedStartDateMax = if limitDate then new Date(limitDate) else null

        # expectedCompletionDate pode ser igual à startDate (mesmo dia permitido)
        @.calculatedMinAllowedDate = if @.startDate then new Date(@.startDate) else null

module.controller("EpicDetailController", EpicDetailController)


#############################################################################
## Epic status display directive
#############################################################################

EpicStatusDisplayDirective = ($template, $compile) ->
    # Display if an epic is open or closed and its status.
    #
    # Example:
    #     tg-epic-status-display(ng-model="epic")
    #
    # Requirements:
    #   - Epic object (ng-model)
    #   - scope.statusById object

    template = $template.get("common/components/status-display.html", true)

    link = ($scope, $el, $attrs) ->
        render = (epic) ->
            status =  $scope.statusById[epic.status]

            html = template({
                is_closed: status.is_closed
                status: status
            })

            html = $compile(html)($scope)
            $el.html(html)

        $scope.$watch $attrs.ngModel, (epic) ->
            render(epic) if epic?

        $scope.$on "$destroy", ->
            $el.off()

    return {
        link: link
        restrict: "EA"
        require: "ngModel"
    }

module.directive("tgEpicStatusDisplay", ["$tgTemplate", "$compile", EpicStatusDisplayDirective])


#############################################################################
## Epic status button directive
#############################################################################

EpicStatusButtonDirective = ($rootScope, $repo, $confirm, $loading, $modelTransform, $compile, $translate, $template) ->
    # Display the status of epic and you can edit it.
    #
    # Example:
    #     tg-epic-status-button(ng-model="epic")
    #
    # Requirements:
    #   - Epic object (ng-model)
    #   - scope.statusById object
    #   - $scope.project.my_permissions

    template = $template.get("common/components/status-button.html", true)

    link = ($scope, $el, $attrs, $model) ->
        isEditable = ->
            return $scope.project.my_permissions.indexOf("modify_epic") != -1

        render = (epic) =>
            status = $scope.statusById[epic.status]

            html = $compile(template({
                status: status
                statuses: $scope.statusList
                editable: isEditable()
            }))($scope)

            $el.html(html)

        save = (status) ->
            currentLoading = $loading()
                .target($el)
                .start()

            transform = $modelTransform.save (epic) ->
                epic.status = status
                return epic

                s  = moment(epic.start_date).startOf('day')
                c  = moment($scope.ctrl.completionDate).startOf('day')

                if !s.isValid() or s.isSameOrAfter(c)
                    $scope.ctrl.startDateError       = 'Confira se a data está correta'
                    $scope.ctrl.startDateBorderAlert = "border:1px solid #e74c3c"
                else
                    $scope.ctrl.startDateError       = ''
                    $scope.ctrl.startDateBorderAlert = ""

                return epic

            onSuccess = ->
                $rootScope.$broadcast("object:updated")
                $scope.$applyAsync()
                currentLoading.finish()

            onError = (response) ->
                rawCode = response?.status?[0] or response?.code or null
                rawCode = rawCode[0] if Array.isArray(rawCode)
                if rawCode
                    $confirm.notify("error", $translate.instant("ERRORS.#{rawCode.toUpperCase()}"))
                else
                    $confirm.notify("error")
                currentLoading.finish()

            transform.then(onSuccess, onError)

        $el.on "click", ".js-edit-status", (event) ->
            event.preventDefault()
            event.stopPropagation()
            return if not isEditable()

            $el.find(".pop-status").popover().open()

        $el.on "click", ".status", (event) ->
            event.preventDefault()
            event.stopPropagation()
            return if not isEditable()

            target = angular.element(event.currentTarget)

            $.fn.popover().closeAll()

            save(target.data("status-id"))

        $scope.$watch () ->
            return $model.$modelValue?.status
        , () ->
            epic = $model.$modelValue
            render(epic) if epic

        $scope.$on "$destroy", ->
            $el.off()

    return {
        link: link
        restrict: "EA"
        require: "ngModel"
    }

module.directive("tgEpicStatusButton", ["$rootScope", "$tgRepo", "$tgConfirm", "$tgLoading", "$tgQueueModelTransformation",
                                        "$compile", "$translate", "$tgTemplate", EpicStatusButtonDirective])
