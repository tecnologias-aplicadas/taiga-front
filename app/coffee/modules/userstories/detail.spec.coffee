###
# This source code is licensed under the terms of the
# GNU Affero General Public License found in the LICENSE file in
# the root directory of this source tree.
#
# Copyright (c) 2021-present Kaleidos INC
###

describe "UserStoryDetailController", ->
    ctrl = scope = $q = $rootScope = null
    mocks = {}
    subscriptions = {}
    legacyChannelBackup = null

    ROUTING_KEY_US = "changes.project.1.userstories"
    ROUTING_KEY_TASKS = "changes.project.1.tasks"

    usModel = (attrs) ->
        return _.extend({
            id: 10, ref: 5, subject: "História", description: "", status: 1, milestone: null,
            total_points: 0, completion_percent_done: 0, completion_percent_progress: 0, _attrs: {}
        }, attrs)

    project = ->
        return {
            id: 1, slug: "projeto", name: "Projeto", members: [], roles: [],
            us_statuses: [], task_statuses: [], points: [], my_permissions: [],
            is_backlog_activated: false, is_kanban_activated: false
        }

    _mocks = ->
        subscriptions = {}
        mocks.events = {
            subscribe: sinon.spy (scope, routingKey, callback) -> subscriptions[routingKey] = callback
        }
        mocks.editingTracker = {isEditing: sinon.stub().returns(false)}
        mocks.rs = {
            userstories: {getByRef: sinon.stub(), storeQueryParams: sinon.stub()}
            tasks: {list: sinon.stub()}
            sprints: {get: sinon.stub()}
        }
        mocks.location = {search: sinon.stub().returns({})}
        mocks.translate = {instant: sinon.stub().returnsArg(0)}
        mocks.projectService = {project: {toJS: -> project()}}
        mocks.modelTransform = {setObject: sinon.stub()}
        mocks.attachmentsFullService = {loadAttachments: sinon.stub()}
        mocks.appMetaService = {setAll: sinon.stub()}
        mocks.navUrls = {resolve: sinon.stub().returns("/url")}
        mocks.wysiwygService = {getHTML: sinon.stub().returns("")}
        mocks.sce = {getTrustedHtml: sinon.stub().returns("")}
        mocks.analytics = {trackEvent: sinon.stub()}

    createController = ->
        inject ($controller, _$q_, _$rootScope_) ->
            $q = _$q_
            $rootScope = _$rootScope_
            scope = $rootScope.$new()

            mocks.rs.userstories.getByRef.returns($q.resolve(usModel()))
            mocks.rs.tasks.list.returns($q.resolve([]))

            ctrl = $controller "UserStoryDetailController", {
                $scope: scope
                $rootScope: $rootScope
                $tgRepo: {}
                $tgConfirm: {}
                $tgResources: mocks.rs
                $routeParams: {pslug: "projeto", usref: "5"}
                $q: $q
                $tgLocation: mocks.location
                $log: {}
                tgAppMetaService: mocks.appMetaService
                $tgNavUrls: mocks.navUrls
                $tgAnalytics: mocks.analytics
                $translate: mocks.translate
                $tgQueueModelTransformation: mocks.modelTransform
                tgErrorHandlingService: {}
                $tgConfig: {config: {}}
                tgProjectService: mocks.projectService
                tgWysiwygService: mocks.wysiwygService
                tgAttachmentsFullService: mocks.attachmentsFullService
                $tgModel: {}
                $sce: mocks.sce
                $tgEvents: mocks.events
                tgEditingTracker: mocks.editingTracker
            }
            $rootScope.$digest()

    emit = (routingKey, message) ->
        subscriptions[routingKey](message)
        $rootScope.$digest()

    expectUsReloaded = (subject) ->
        mocks.rs.userstories.getByRef.reset()
        mocks.rs.userstories.getByRef.returns($q.resolve(usModel({subject: subject, status: 2})))

    beforeEach ->
        module "taigaBase"
        module "taigaUserStories"

        legacyChannelBackup = window.legacyChannel
        window.legacyChannel = {next: sinon.stub()}

        _mocks()
        createController()

    afterEach ->
        window.legacyChannel = legacyChannelBackup

    it "assina as chaves de histórias e de tarefas do projeto com o scope da tela e sem selfNotification", ->
        expect(mocks.events.subscribe).to.have.been.calledTwice
        expect(subscriptions).to.have.all.keys(ROUTING_KEY_US, ROUTING_KEY_TASKS)
        for call in mocks.events.subscribe.getCalls()
            expect(call.args[0]).to.be.equal(scope)
            expect(call.args[3]).to.be.undefined

    it "evento da história aberta reconsulta o servidor e o scope passa a ter o objeto devolvido", ->
        expectUsReloaded("Alterada pela T·IA")

        emit(ROUTING_KEY_US, {type: "change", matches: "userstories.userstory", pk: 10})

        expect(mocks.rs.userstories.getByRef).to.have.been.calledOnce
        expect(scope.us.subject).to.be.equal("Alterada pela T·IA")
        expect(scope.us.status).to.be.equal(2)

    it "evento de outra história não consulta nem altera o scope", ->
        expectUsReloaded("Outra")

        emit(ROUTING_KEY_US, {type: "change", matches: "userstories.userstory", pk: 99})

        expect(mocks.rs.userstories.getByRef).not.to.have.been.called
        expect(scope.us.subject).to.be.equal("História")

    it "evento em lote com lista de pks contendo a história consulta", ->
        expectUsReloaded("Movida em lote")

        emit(ROUTING_KEY_US, {type: "change", matches: "userstories.userstory", pk: [3, 10, 12]})

        expect(mocks.rs.userstories.getByRef).to.have.been.calledOnce
        expect(scope.us.subject).to.be.equal("Movida em lote")

    it "evento durante edição não consulta nem altera o scope, e consulta ao terminar a edição", ->
        mocks.editingTracker.isEditing.returns(true)
        expectUsReloaded("Alterada pela T·IA")

        emit(ROUTING_KEY_US, {type: "change", matches: "userstories.userstory", pk: 10})

        expect(mocks.rs.userstories.getByRef).not.to.have.been.called
        expect(scope.us.subject).to.be.equal("História")

        mocks.editingTracker.isEditing.returns(false)
        $rootScope.$broadcast("editing:idle")
        $rootScope.$digest()

        expect(mocks.rs.userstories.getByRef).to.have.been.calledOnce
        expect(scope.us.subject).to.be.equal("Alterada pela T·IA")

    it "vários eventos durante a edição viram uma só consulta ao terminar", ->
        mocks.editingTracker.isEditing.returns(true)
        expectUsReloaded("Alterada pela T·IA")

        emit(ROUTING_KEY_US, {type: "change", matches: "userstories.userstory", pk: 10})
        emit(ROUTING_KEY_US, {type: "change", matches: "userstories.userstory", pk: 10})

        mocks.editingTracker.isEditing.returns(false)
        $rootScope.$broadcast("editing:idle")
        $rootScope.$digest()

        expect(mocks.rs.userstories.getByRef).to.have.been.calledOnce

    it "evento de exclusão da própria história não consulta", ->
        expectUsReloaded("Apagada")

        emit(ROUTING_KEY_US, {type: "delete", matches: "userstories.userstory", pk: 10})

        expect(mocks.rs.userstories.getByRef).not.to.have.been.called
        expect(scope.us.subject).to.be.equal("História")

    it "recarga da história por evento pede aos campos personalizados que reconsultem os valores", ->
        reloadValues = sinon.spy()
        scope.$new().$on("custom-attributes-values:reload", reloadValues)
        expectUsReloaded("Alterada pela T·IA")

        emit(ROUTING_KEY_US, {type: "change", matches: "userstories.userstory", pk: 10})

        expect(reloadValues).to.have.been.calledOnce

    it "recarga só da lista de tarefas não reconsulta os campos personalizados", ->
        reloadValues = sinon.spy()
        scope.$new().$on("custom-attributes-values:reload", reloadValues)
        scope.tasks = [{id: 7, status: 1}]
        mocks.rs.tasks.list.returns($q.resolve([{id: 7, status: 2}]))

        emit(ROUTING_KEY_TASKS, {type: "change", matches: "tasks.task", pk: 7})

        expect(reloadValues).not.to.have.been.called

    it "durante edição a reconsulta dos campos personalizados espera o fim da edição", ->
        reloadValues = sinon.spy()
        scope.$new().$on("custom-attributes-values:reload", reloadValues)
        mocks.editingTracker.isEditing.returns(true)
        expectUsReloaded("Alterada pela T·IA")

        emit(ROUTING_KEY_US, {type: "change", matches: "userstories.userstory", pk: 10})
        expect(reloadValues).not.to.have.been.called

        mocks.editingTracker.isEditing.returns(false)
        $rootScope.$broadcast("editing:idle")
        $rootScope.$digest()

        expect(reloadValues).to.have.been.calledOnce

    it "evento de tarefa da história recarrega a lista de tarefas sem reconsultar a história", ->
        scope.tasks = [{id: 7, status: 1}]
        mocks.rs.userstories.getByRef.reset()
        mocks.rs.tasks.list.reset()
        mocks.rs.tasks.list.returns($q.resolve([{id: 7, status: 2}]))

        emit(ROUTING_KEY_TASKS, {type: "change", matches: "tasks.task", pk: 7})

        expect(mocks.rs.tasks.list).to.have.been.calledOnce
        expect(mocks.rs.userstories.getByRef).not.to.have.been.called
        expect(scope.tasks[0].status).to.be.equal(2)

    it "evento de tarefa de outra história não recarrega a lista", ->
        scope.tasks = [{id: 7, status: 1}]
        mocks.rs.tasks.list.reset()

        emit(ROUTING_KEY_TASKS, {type: "change", matches: "tasks.task", pk: 99})

        expect(mocks.rs.tasks.list).not.to.have.been.called

    it "tarefa criada recarrega a lista mesmo sem estar nela", ->
        scope.tasks = []
        mocks.rs.tasks.list.reset()
        mocks.rs.tasks.list.returns($q.resolve([{id: 8, status: 1}]))

        emit(ROUTING_KEY_TASKS, {type: "create", matches: "tasks.task", pk: 8})

        expect(mocks.rs.tasks.list).to.have.been.calledOnce
        expect(scope.tasks.length).to.be.equal(1)

    it "object:updated recarrega enquanto a tela está aberta e deixa de recarregar depois que o scope é destruído", ->
        mocks.rs.userstories.getByRef.reset()
        $rootScope.$broadcast("object:updated")
        $rootScope.$digest()
        expect(mocks.rs.userstories.getByRef).to.have.been.calledOnce

        scope.$destroy()
        mocks.rs.userstories.getByRef.reset()
        $rootScope.$broadcast("object:updated")
        $rootScope.$digest()
        expect(mocks.rs.userstories.getByRef).not.to.have.been.called
