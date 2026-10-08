class DependenciesListController
  @.$inject = [
    "$rootScope"
    "$scope"
    "$timeout"
    "$tgConfirm"
    "$tgResources"
    "$q"
    "tgCurrentUserService"
    "$translate"
  ]

  constructor: (
    @rootScope
    @scope
    @timeout
    @confirm
    @rs
    @q
    @currentUserService
    @translate
  ) ->
    @.dependencyType = "BKBY"
    @.selectedItems = []
    @.searchText = ""
    @.searchListItems = []
    @.loading = false
    @.dependencies = []
    @.itemType = "userstory"
    @.user = @currentUserService.getUser()

    @scope.$on "dependencies:updated", =>
      @loadDependencies()

    @scope.$watch "vm.shared.dependencies", (newVal, oldVal) =>
      return if newVal is oldVal and @dependencies.length > 0
      @loadDependencies()

    @.watchItemType()

    @scope.$watch "vm.item", (item) =>
      return unless item?.id
      @loadDependencies()

  getProjectId: ->
    return @.project?.id if @.project?.id?
    return @.item?.project if @.item?.project?
    return null

  getCardTypeFromItem: (item) ->
    name = item?._name

    map =
      userstories: "userstory"
      tasks: "task"
      issues: "issue"
      epics: "epic"

    return map[name] if map[name]
    return "userstory"

  watchItemType: ->
    @scope.$watch "vm.itemType", (newValue, oldValue) =>
      return unless newValue? and newValue != oldValue

      @.searchListItems = []

      if @.searchText?.trim()
        @.filterTickets(@.searchText)

  onItemTypeChange: ->
    @.searchListItems = []

    if @.searchText?.trim()
      @.filterTickets(@.searchText)


  openDependenciesModal: (closeFn) ->
    @searchText = ""
    @searchListItems = []
    @selectedItems = []
    @._closeLightbox = closeFn or null
    
  closeModal: ->
    @.selectedItems = []

  filterTickets: (filterText) ->
    if !filterText or !filterText.trim()
      @.searchListItems = []
      return

    projectId = @.getProjectId()
    unless projectId
      @confirm.notify("error", @translate.instant("COMMON.DEPENDENCIES.NOTIFICATIONS.LOAD_INVALID"))
      return

    @.loading = true

    if @.searchTimeoutPromise?
      @.searchTimeoutPromise.resolve()

    @.searchTimeoutPromise = @q.defer()

    apiEndpoint = switch @.itemType
      when "issue" then @rs.issues
      when "userstory" then @rs.userstories
      when "task" then @rs.tasks
      when "epic" then @rs.epics
      else @rs.userstories

    currentItem = @.getCurrentItem()

    alreadyRelatedIds = new Set(
      @.dependencies
        .filter (dep) => dep.ticket.type is @.itemType
        .map (dep) => dep.ticket.id
    )

    apiEndpoint.listInAllProjects({
      project: projectId
      q: filterText
    }, @.searchTimeoutPromise.promise)
      .then (data) =>
        @.searchListItems = []

        return unless data

        items = if data.toJS then data.toJS() else if Array.isArray(data) then data else [data]

        for item in items
          if item.get
            itemId = item.get("id")
            continue if alreadyRelatedIds.has(itemId) or itemId is currentItem?.id
            @.searchListItems.push
              id: itemId
              ref: item.get("ref")
              subject: item.get("subject")
              status_name: item.getIn(["status_extra_info", "name"]) or "-"
          else
            continue if alreadyRelatedIds.has(item.id) or item.id is currentItem?.id
            @.searchListItems.push
              id: item.id
              ref: item.ref
              subject: item.subject
              status_name: item.status_extra_info?.name or "-"
      .catch (error) =>
        @confirm.notify("error", @translate.instant("COMMON.DEPENDENCIES.NOTIFICATIONS.LOAD_ERROR"))
        console.error("Erro ao filtrar tickets:", error)
        @.searchListItems = []
      .finally =>
        @.loading = false


  getCurrentItem: ->
    return @.item or null

  onSearchUpdate: (filterText) ->
    if @.searchTimeout
      @timeout.cancel(@.searchTimeout)

    @.searchTimeout = @timeout =>
      @.filterTickets(filterText)
    , 300

  isItemSelected: (item) ->
    return @.selectedItems.some (i) -> i.ref == item.ref

  toggleItemSelection: (item) ->
    index = @.selectedItems.findIndex (i) -> i.ref == item.ref

    if index > -1
      @.selectedItems.splice(index, 1)
    else
      @.selectedItems.push(item)
  
  saveAndClose: ->
    return if @.loading
    @.saveDependencies(@.selectedItems, @.dependencyType)
      .then =>
        @.closeModal()
        @._closeLightbox?()

  saveDependencies: (selectedItems, dependencyType) =>
    deferred = @q.defer()

    return deferred.promise unless selectedItems?.length

    sourceItem = @getCurrentItem()
    projectId = @.getProjectId()
    sourceType = @.getCardTypeFromItem(sourceItem)

    unless sourceItem?.id and projectId and sourceType
      @confirm.notify("error", @translate.instant("COMMON.DEPENDENCIES.NOTIFICATIONS.CREATE_INVALID_IDS"))
      deferred.reject("Dados inválidos")
      return deferred.promise

    filteredItems = selectedItems.filter (selectedItem) =>
      selectedItem?.id? and selectedItem.id isnt sourceItem.id

    if filteredItems.length is 0
      @confirm.notify("error", @translate.instant("ERRORS.SELF_RELATION_NOT_ALLOWED"))
      deferred.reject("Nenhum item válido para relacionar")
      return deferred.promise

    @.loading = true

    promises = filteredItems.map (selectedItem) =>
      @rs.cardRelations.createDependency(
        projectId,
        sourceType,
        sourceItem.id,
        @.itemType,
        selectedItem.id,
        dependencyType
      )

    @q.all(promises)
      .then (results) =>
        @.selectedItems = []
        return @.loadDependencies()
      .then =>
        @rootScope.$broadcast("dependencies:updated")
        @rootScope.$broadcast("object:updated")
        @confirm.notify("success", @translate.instant("COMMON.DEPENDENCIES.NOTIFICATIONS.CREATE_SUCCESS"))
        deferred.resolve(true)
      .catch (error) =>
        console.error("Erro ao criar dependências:", error)
        errorCode = @_extractErrorCode(error)
        msg = if errorCode
          @translate.instant("ERRORS.#{errorCode}")
        else
          @translate.instant("COMMON.DEPENDENCIES.NOTIFICATIONS.CREATE_ERROR")
        @confirm.notify("error", msg)
        deferred.reject(error)
      .finally =>
        @.loading = false

    return deferred.promise


  loadDependencies: ->
    @loading = true

    item = @getCurrentItem()
    return unless item

    projectId = item?.project or item?._attrs?.project
    cardType = @getCurrentCardType(item)
    cardRef = item?.ref or item?._attrs?.ref

    unless projectId and cardType and cardRef
      @confirm.notify("error", @translate.instant("COMMON.DEPENDENCIES.NOTIFICATIONS.LOAD_INVALID"))
      @loading = false
      return

    unless @rs.cardRelations?.getDependencies
      console.warn("Serviço cardRelations.getDependencies indisponível.")
      @loading = false
      return

    return @rs.cardRelations.getDependencies(projectId, cardType, cardRef)
      .then (response) =>
        @dependencies = @normalizeDependencies(response, item)
        return @dependencies
      .catch (error) =>
        @confirm.notify("error", @translate.instant("COMMON.DEPENDENCIES.NOTIFICATIONS.LOAD_ERROR"))
        console.error("Erro ao carregar dependências:", error)
        throw error
      .finally =>
        @loading = false


  getFormattedDate: (isoDate) ->
    return "-" unless isoDate
    format = @translate.instant("COMMON.DEPENDENCIES.DATE_FORMAT")
    return moment(isoDate).format(format)

  viewDependency: (dependency) ->
    ticketType = dependency?.ticket?.type
    ticketRefNumber = dependency?.ticket?.ref_number
    projectSlug = @getProjectSlug()

    return unless ticketType and ticketRefNumber? and projectSlug

    url = @buildTicketUrl(ticketType, ticketRefNumber, projectSlug)
    return unless url

    window.open(url, "_blank")
    return

  confirmAndRemoveDependency: (dependency) =>
    title = @translate.instant("COMMON.DEPENDENCIES.NOTIFICATIONS.REMOVE_CONFIRM_TITLE")
    message = @translate.instant("COMMON.DEPENDENCIES.NOTIFICATIONS.REMOVE_CONFIRM_MESSAGE", {
      ticketRef: dependency.ticket.ref_number
      ticketSubject: dependency.ticket.subject or ""
    })

    @confirm.askOnDelete(title, message).then (askResponse) =>
      @removeDependency(dependency)
        .then =>
          askResponse.finish()
          @scope.$emit("dependencies:updated")
          @confirm.notify("success", @translate.instant("COMMON.DEPENDENCIES.NOTIFICATIONS.REMOVE_SUCCESS"))
        .catch (error) =>
          askResponse.finish(false)
          errorCode = error?.data?._error_code
          msg = if errorCode
            @translate.instant("ERRORS.#{errorCode}")
          else
            @translate.instant("COMMON.DEPENDENCIES.NOTIFICATIONS.REMOVE_ERROR")
          @confirm.notify("error", msg)

  _extractErrorCode: (error) ->
    code = error?.data?.code or
           error?.data?._error_code or
           error?.data?.relation_type?[0]?._error_code or
           null
    code = code[0] if Array.isArray(code)
    return code?.toUpperCase() or null

  updateDependency: (dependency) =>
    deferred = @q.defer()

    unless @rs.cardRelations?.updateDependency
      deferred.reject("Serviço indisponível")
      return deferred.promise

    @rs.cardRelations.updateDependency(dependency.id, dependency._newRelationType)
      .then (result) =>
        @confirm.notify("success", @translate.instant("COMMON.DEPENDENCIES.NOTIFICATIONS.UPDATE_SUCCESS"))
        dependency._editing = false
        @rootScope.$broadcast("dependencies:updated")
        @rootScope.$broadcast("object:updated")
        deferred.resolve(result)
      .catch (error) =>
        errorCode = @_extractErrorCode(error)
        msg = if errorCode
          @translate.instant("ERRORS.#{errorCode}")
        else
          @translate.instant("COMMON.DEPENDENCIES.NOTIFICATIONS.UPDATE_ERROR")
        @confirm.notify("error", msg)
        deferred.reject(error)

    return deferred.promise

  resolveDependency: (dependency) =>
    relationId = dependency?.id

    unless relationId
      @confirm.notify("error", @translate.instant("COMMON.DEPENDENCIES.NOTIFICATIONS.RESOLVE_ERROR"))
      return

    unless @rs.cardRelations?.resolveDependency
      @confirm.notify("error", @translate.instant("COMMON.DEPENDENCIES.NOTIFICATIONS.RESOLVE_ERROR"))
      return

    title = @translate.instant("COMMON.DEPENDENCIES.NOTIFICATIONS.RESOLVE_CONFIRM_TITLE")
    message = @translate.instant("COMMON.DEPENDENCIES.NOTIFICATIONS.RESOLVE_CONFIRM_MESSAGE")
    subtitle = @translate.instant("COMMON.DEPENDENCIES.NOTIFICATIONS.RESOLVE_CONFIRM_SUBTITLE", {
      ticketRef: dependency.ticket.ref_number
      ticketSubject: dependency.ticket.subject or ""
    })

    @confirm.ask(title, message, subtitle).then (askResponse) =>
      @rs.cardRelations.resolveDependency(relationId)
        .then (result) =>
          askResponse.finish()
          dependency.is_resolved = true
          @rootScope.$broadcast("object:updated")
          @confirm.notify("success", @translate.instant("COMMON.DEPENDENCIES.NOTIFICATIONS.RESOLVE_SUCCESS"))
        .catch (error) =>
          askResponse.finish(false)
          errorCode = @_extractErrorCode(error)
          msg = if errorCode
            @translate.instant("ERRORS.#{errorCode}")
          else
            @translate.instant("COMMON.DEPENDENCIES.NOTIFICATIONS.RESOLVE_ERROR")
          @confirm.notify("error", msg)

  removeDependency: (dependency) =>
    deferred = @q.defer()

    relationId = dependency?.id

    unless relationId
      deferred.reject("ID da relação inválido")
      return deferred.promise

    unless @rs.cardRelations?.removeDependency
      deferred.reject("Serviço indisponível")
      return deferred.promise

    @rs.cardRelations.removeDependency(relationId)
      .then (result) =>
        @dependencies = @dependencies.filter (dep) -> dep.id isnt relationId
        @rootScope.$broadcast("dependencies:updated")
        @rootScope.$broadcast("object:updated")
        deferred.resolve(result)
      .catch (error) =>
        deferred.reject(error)

    return deferred.promise

  getDependencyTextBySide: (relationType, side, sourceType, targetType) ->
    sourceMap =
      RT: "COMMON.DEPENDENCIES.SOURCE_RELATION_TYPES.RELATIONSHIP_RT"
      BK: "COMMON.DEPENDENCIES.SOURCE_RELATION_TYPES.RELATIONSHIP_BK"
      BKBY: "COMMON.DEPENDENCIES.SOURCE_RELATION_TYPES.RELATIONSHIP_BKBY"
      DPON: "COMMON.DEPENDENCIES.SOURCE_RELATION_TYPES.RELATIONSHIP_DPON"
      DPME: "COMMON.DEPENDENCIES.SOURCE_RELATION_TYPES.RELATIONSHIP_DPME"
      DUBY: "COMMON.DEPENDENCIES.SOURCE_RELATION_TYPES.RELATIONSHIP_DUBY"
      DUFROM: "COMMON.DEPENDENCIES.SOURCE_RELATION_TYPES.RELATIONSHIP_DUFROM"
      DWT: "COMMON.DEPENDENCIES.SOURCE_RELATION_TYPES.RELATIONSHIP_DWT"
      LTDWT: "COMMON.DEPENDENCIES.SOURCE_RELATION_TYPES.RELATIONSHIP_LTDWT"

    targetMap =
      RT: "COMMON.DEPENDENCIES.TARGET_RELATION_TYPES.RELATIONSHIP_RT"
      BK: "COMMON.DEPENDENCIES.TARGET_RELATION_TYPES.RELATIONSHIP_BK"
      BKBY: "COMMON.DEPENDENCIES.TARGET_RELATION_TYPES.RELATIONSHIP_BKBY"
      DPON: "COMMON.DEPENDENCIES.TARGET_RELATION_TYPES.RELATIONSHIP_DPON"
      DPME: "COMMON.DEPENDENCIES.TARGET_RELATION_TYPES.RELATIONSHIP_DPME"
      DUBY: "COMMON.DEPENDENCIES.TARGET_RELATION_TYPES.RELATIONSHIP_DUBY"
      DUFROM: "COMMON.DEPENDENCIES.TARGET_RELATION_TYPES.RELATIONSHIP_DUFROM"
      DWT: "COMMON.DEPENDENCIES.TARGET_RELATION_TYPES.RELATIONSHIP_DWT"
      LTDWT: "COMMON.DEPENDENCIES.TARGET_RELATION_TYPES.RELATIONSHIP_LTDWT"

    key =
      if side is "target"
        targetMap[relationType]
      else
        sourceMap[relationType]

    return relationType unless key
    return relationType unless relationType
    return relationType unless sourceType
    return relationType unless targetType

    sourceKind = @translate.instant("ACTIVITY.CARD_TYPES." + sourceType)
    targetKind = @translate.instant("ACTIVITY.CARD_TYPES." + targetType)

    return @translate.instant(key,
      source_kind: sourceKind
      target_kind: targetKind
    )

  getRelationSide: (dep, currentId) ->
    if String(dep.source_id) is String(currentId)
      return "source"

    if String(dep.target_id) is String(currentId)
      return "target"

    return null

  getCurrentCardType: (item) ->
    name = item?._name

    map =
      userstories: "userstory"
      tasks: "task"
      issues: "issue"
      epics: "epic"

    return map[name] if map[name]
    return item?.type if item?.type
    return "userstory"

  getProjectSlug: ->
    return @.project?.slug or null

  buildTicketUrl: (ticketType, ticketRefNumber, projectSlug) ->
    return null unless ticketType and ticketRefNumber? and projectSlug

    switch ticketType
      when "userstory" then "/project/#{projectSlug}/us/#{ticketRefNumber}"
      when "task" then "/project/#{projectSlug}/task/#{ticketRefNumber}"
      when "issue" then "/project/#{projectSlug}/issue/#{ticketRefNumber}"
      when "epic" then "/project/#{projectSlug}/epic/#{ticketRefNumber}"
      else null

  normalizeDependencies: (dependencies, currentItem) ->
    items =
      if !dependencies
        []
      else if dependencies.data?.results and Array.isArray(dependencies.data.results)
        dependencies.data.results
      else if dependencies.data and Array.isArray(dependencies.data)
        dependencies.data
      else if dependencies.results and Array.isArray(dependencies.results)
        dependencies.results
      else if dependencies.toJS
        dependencies.toJS()
      else if Array.isArray(dependencies)
        dependencies
      else
        [dependencies]

    currentId = currentItem?._attrs?.id or currentItem?.id

    return items.map (dep) =>
      side = @getRelationSide(dep, currentId)
      isCurrentSource = side is "source"

      relatedType = if isCurrentSource then dep.target_type else dep.source_type
      relatedId = if isCurrentSource then dep.target_id else dep.source_id
      relatedRefNumber = if isCurrentSource then dep.target_ref else dep.source_ref

      relatedRefPrefix = switch relatedType
        when "userstory" then "US"
        when "task" then "TASK"
        when "issue" then "ISSUE"
        when "epic" then "EPIC"
        else String(relatedType or "").toUpperCase()

      relatedRefLabel = if relatedRefNumber? then "#{relatedRefPrefix}-#{relatedRefNumber}" else null

      {
        id: dep.id
        relation_type: dep.relation_type or dep.type
        relation_side: side
        type_text: @getDependencyTextBySide(dep.relation_type or dep.type, side, dep.source_type, dep.target_type)
        date: dep.created_date or dep.date or dep.modified_date
        user: dep.created_by_username or dep.user_name or dep.created_by_full_name or @translate.instant("COMMON.DEPENDENCIES.UNASSIGNED")
        is_active: if dep.is_active? then dep.is_active else true
        is_resolved: dep.is_resolved or false
        ticket:
          id: relatedId
          type: relatedType
          ref_number: relatedRefNumber
          ref_label: relatedRefLabel
          subject: dep.target_subject or dep.source_subject or dep.subject or ""
        raw: dep
      }

angular.module("taigaComponents")
  .controller("DependenciesListController", DependenciesListController)