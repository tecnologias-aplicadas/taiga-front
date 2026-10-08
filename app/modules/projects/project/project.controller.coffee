###
# This source code is licensed under the terms of the
# GNU Affero General Public License found in the LICENSE file in
# the root directory of this source tree.
#
# Copyright (c) 2021-present Kaleidos INC
###

class ProjectController
    @.$inject = [
        "$routeParams",
        "tgAppMetaService",
        "$tgAuth",
        "$translate",
        "tgProjectService",
        "$tgConfig",
        "$tgNavUrls",
        "$location",
        "$tgHttp",
        "$tgUrls"
    ]

    constructor: (@routeParams, @appMetaService, @auth, @translate, @projectService, @config, @navUrls, @location, @http, @urls) ->
        @.user = @auth.userData

        taiga.defineImmutableProperty @, "project", () => return @projectService.project
        taiga.defineImmutableProperty @, "members", () => return @projectService.activeMembers
        taiga.defineImmutableProperty @, "isAuthenticated", () => return !!@.user

        nextUrl = @location.url()
        @.registerUrl = "#{@navUrls.resolve("register")}?next=#{nextUrl}"
        @.loginUrl = "#{@navUrls.resolve("login")}?next=#{nextUrl}"

        @.publicRegisterEnabled = @config.get("publicRegisterEnabled")
        @.schedulableSegments = []

        @appMetaService.setfn @._setMeta.bind(this)
        @_decorateDates()
        @_loadSchedulableBar()

    _setMeta: ()->
        return null if !@.project

        ctx = {projectName: @.project.get("name")}

        return {
            title: @translate.instant("PROJECT.PAGE_TITLE", ctx)
            description: @.project.get("description")
        }

    _decorateDates: ->
        return unless @projectService.project?

        dateIsValid = (d) -> d?.isValid()
        diffDays = (a, b) ->
            return 0 unless dateIsValid(a) and dateIsValid(b)
            b.diff a, 'days'

        clamp = (value, min = 0, max = 100) -> Math.min max, Math.max min, value

        prj = @projectService.project

        # parsing das datas (strings ISO → Date)
        start    = moment prj.get 'start_date'
        expected = moment prj.get 'expected_end_date'
        ending   = moment prj.get 'end_date'
        today    = moment()

        # status do projeto
        @isActiveProject = not ending.isValid()   # true → ativo | false → finalizado

        # formatação para exibição (pt-BR)
        fmt = 'DD/MM/YYYY'
        @.dates =
            start:       if start.isValid()    then start.format(fmt)    else '--/--/----'
            expectedEnd: if expected.isValid() then expected.format(fmt) else '--/--/----'
            end:         if ending.isValid()   then ending.format(fmt)   else '--/--/----'

        # total = início até previsão de fim
        @totalDays   = diffDays start, expected

        # decorrido: se projeto finalizado usa data de término, senão usa hoje
        elapsedRef   = if ending.isValid() then ending else today
        @elapsedDays = diffDays start, elapsedRef

        if ending.isValid()
            # projeto finalizado: positivo = terminou antes, negativo = atrasou
            @remainDays = diffDays ending, expected
        else
            # projeto ativo: positivo = faltam dias, negativo = já venceu
            @remainDays = diffDays today, expected

        @.isOverdue = @remainDays < 0

        @.progressPercent = clamp Math.round(@elapsedDays / @totalDays * 100)

    _loadSchedulableBar: ->
        return unless @projectService.project?

        projectId = @projectService.project.get('id')
        url = @urls.resolve("epics") + "/history_pd"

        @http.get(url, {project: projectId})
            .then (result) =>
                response = result.data
                rows = response.monthly or []

                lastDataIdx = 0
                rows.forEach (row, i) ->
                    if row.has_snapshot
                        lastDataIdx = i

                statsRow = rows[lastDataIdx]
                schedPct   = Math.round(statsRow?.scheduled_impact_done   or 0)
                unschedPct = Math.round(statsRow?.unscheduled_impact_done or 0)

                return if schedPct is 0 and unschedPct is 0

                @.schedulableBars = []

                if schedPct > 0
                    @.schedulableBars.push
                        value: "#{schedPct}%"
                        color: "#6994EA"
                        label: "Planejável"

                if unschedPct > 0
                    @.schedulableBars.push
                        value: "#{unschedPct}%"
                        color: "#ca81be"
                        label: "Não planejável"


angular.module("taigaProjects").controller("Project", ProjectController)