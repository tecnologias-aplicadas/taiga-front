###
# This source code is licensed under the terms of the
# GNU Affero General Public License found in the LICENSE file in
# the root directory of this source tree.
#
# Copyright (c) 2021-present Kaleidos INC
###

taiga = @.taiga
trim = taiga.trim
getRandomDefaultColor = taiga.getRandomDefaultColor


class CreateEpicController
    @.$inject = [
        "$tgConfirm"
        "tgProjectService",
        "tgEpicsService",
        "$tgAnalytics"
    ]

    constructor: (@confirm, @projectService, @epicsService, @analytics) ->
        # NOTE: To use Checksley setFormErrors() and validateForm()
        #       are defined in the directive.

        # NOTE: We use project as no inmutable object to make
        #       the code compatible with the old code
        @.project = @projectService.project.toJS()

        @.newEpic = {
            color: getRandomDefaultColor()
            status: @.project.default_epic_status
            tags: []
        }
        @.attachments = Immutable.List()

        @.loading = false

    createEpic: () -> 
        return if not @.validateForm()

        # Foram criados os campos .._date_ui para evitar conflitos entre o Angular, o datepicker e o backend.
        # O datepicker exibe e edita datas no formato DD/MM/YYYY, enquanto o backend espera o formato YYYY-MM-DD.
        # Embora a conversão correta para o backend seja feita no submit do formulário (e somente nesse momento),
        # o Angular detecta "magicamente" diferenças entre os dados do backend e os valores exibidos no datepicker.
        # Isso faz com que, o submit do formulário resulte no Error: [ngModel:datefmt] Expected `2025-05-27` to be a date
        # Esse erro não impede o submit do formulário, mas fica nos logs do front
        # Para resolver isso, os campos .._date_ui são usados exclusivamente no datepicker,
        # mantendo os campos originais intactos até o momento do submit, quando a conversão final é feita.
        @.newEpic.start_date = moment(@.newEpic.start_date_ui).format("YYYY-MM-DD")
        @.newEpic.expected_completion_date = moment(@.newEpic.expected_completion_date_ui).format("YYYY-MM-DD")

        @.loading = true



        @epicsService.createEpic(@.newEpic, @.attachments)
            .then (response) => # On success
                @analytics.trackEvent("epic", "create", "create epic", 1)
                @.onCreateEpic()
                @.loading = false
            .catch (response) => # On error
                @.loading = false
                @.setFormErrors(response.data)
                if response.data._error_message
                    @confirm.notify("error", response.data._error_message)

    # Color selector
    selectColor: (color) ->
        @.newEpic.color = color

    # Tags
    addTag: (name, color) ->
        name = trim(name.toLowerCase())

        if not _.find(@.newEpic.tags, (it) -> it[0] == name)
            @.newEpic.tags.push([name, color])

    deleteTag: (tag) ->
        _.remove @.newEpic.tags, (it) -> it[0] == tag[0]

    # Attachments
    addAttachment: (attachment) ->
        @.attachments.push(attachment)

angular.module("taigaEpics").controller("CreateEpicCtrl", CreateEpicController)
