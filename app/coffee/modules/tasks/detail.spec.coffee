###
# This source code is licensed under the terms of the
# GNU Affero General Public License found in the LICENSE file in
# the root directory of this source tree.
#
# Copyright (c) 2021-present Kaleidos INC
###

describe "TaskDetailController", ->
    ctrl = scope = $q = $rootScope = null
    mocks = {}
    subscriptions = {}
    legacyChannelBackup = null

    ROUTING_KEY = "changes.project.1.tasks"

    taskModel = (attrs) ->
        return _.extend({
            id: 20, ref: 8, subject: "Tarefa", status: 1, milestone: null, user_story: null,
            neighbors: {}, description_html: "", completion_percent_done: 0,
            completion_percent_progress: 0, _attrs: {}
        }, attrs)

    project = ->
        return {
            id: 1, slug: "projeto", name: "Projeto", members: [], roles: [],
            task_statuses: [], my_permissions: [],
            is_backlog_activated: false, is_kanban_activated: false
        }

    _mocks = ->
        subscriptions = {}
        mocks.events = {
            subscribe: sinon.spy (scope, routingKey, callback) -> subscriptions[routingKey] = callback
        }
        mocks.editingTracker = {isEditing: sinon.stub().returns(false)}
        mocks.rs = {
            tasks: {getByRef: sinon.stub()}
            userstories: {get: sinon.stub()}
            sprints: {get: sinon.stub()}
        }
        mocks.translate = {instant: sinon.stub().returnsArg(0)}
        mocks.projectService = {project: {toJS: -> project()}}
        mocks.modelTransform = {setObject: sinon.stub()}
        mocks.attachmentsFullService = {loadAttachments: sinon.stub()}
        mocks.appMetaService = {setAll: sinon.stub()}
        mocks.navUrls = {resolve: sinon.stub().returns("/url")}
        mocks.analytics = {trackEvent: sinon.stub()}

    createController = ->
        inject ($controller, _$q_, _$rootScope_) ->
            $q = _$q_
            $rootScope = _$rootScope_
            scope = $rootScope.$new()

            mocks.rs.tasks.getByRef.returns($q.resolve(taskModel()))

            ctrl = $controller "TaskDetailController", {
                $scope: scope
                $rootScope: $rootScope
                $tgRepo: {}
                $tgConfirm: {}
                $tgResources: mocks.rs
                $routeParams: {pslug: "projeto", taskref: "8"}
                $q: $q
                $tgLocation: {}
                $log: {}
                tgAppMetaService: mocks.appMetaService
                $tgNavUrls: mocks.navUrls
                $tgAnalytics: mocks.analytics
                $translate: mocks.translate
                $tgQueueModelTransformation: mocks.modelTransform
                tgErrorHandlingService: {}
                tgProjectService: mocks.projectService
                tgAttachmentsFullService: mocks.attachmentsFullService
                $tgEvents: mocks.events
                tgEditingTracker: mocks.editingTracker
            }
            $rootScope.$digest()

    emit = (message) ->
        subscriptions[ROUTING_KEY](message)
        $rootScope.$digest()

    expectTaskReloaded = (subject) ->
        mocks.rs.tasks.getByRef.reset()
        mocks.rs.tasks.getByRef.returns($q.resolve(taskModel({subject: subject, status: 2})))

    beforeEach ->
        module "taigaBase"
        module "taigaTasks"

        legacyChannelBackup = window.legacyChannel
        window.legacyChannel = {next: sinon.stub()}

        _mocks()
        createController()

    afterEach ->
        window.legacyChannel = legacyChannelBackup

    it "assina a chave de tarefas do projeto com o scope da tela e sem selfNotification", ->
        expect(mocks.events.subscribe).to.have.been.calledOnce
        expect(subscriptions).to.have.all.keys(ROUTING_KEY)
        expect(mocks.events.subscribe.firstCall.args[0]).to.be.equal(scope)
        expect(mocks.events.subscribe.firstCall.args[3]).to.be.undefined

    it "evento da tarefa aberta reconsulta o servidor e o scope passa a ter o objeto devolvido", ->
        expectTaskReloaded("Alterada pela T·IA")

        emit({type: "change", matches: "tasks.task", pk: 20})

        expect(mocks.rs.tasks.getByRef).to.have.been.calledOnce
        expect(scope.task.subject).to.be.equal("Alterada pela T·IA")
        expect(scope.task.status).to.be.equal(2)

    it "evento de outra tarefa não consulta nem altera o scope", ->
        expectTaskReloaded("Outra")

        emit({type: "change", matches: "tasks.task", pk: 99})

        expect(mocks.rs.tasks.getByRef).not.to.have.been.called
        expect(scope.task.subject).to.be.equal("Tarefa")

    it "evento em lote com lista de pks contendo a tarefa consulta", ->
        expectTaskReloaded("Movida em lote")

        emit({type: "change", matches: "tasks.task", pk: [1, 20, 30]})

        expect(mocks.rs.tasks.getByRef).to.have.been.calledOnce
        expect(scope.task.subject).to.be.equal("Movida em lote")

    it "evento durante edição não consulta nem altera o scope, e consulta ao terminar a edição", ->
        mocks.editingTracker.isEditing.returns(true)
        expectTaskReloaded("Alterada pela T·IA")

        emit({type: "change", matches: "tasks.task", pk: 20})

        expect(mocks.rs.tasks.getByRef).not.to.have.been.called
        expect(scope.task.subject).to.be.equal("Tarefa")

        mocks.editingTracker.isEditing.returns(false)
        $rootScope.$broadcast("editing:idle")
        $rootScope.$digest()

        expect(mocks.rs.tasks.getByRef).to.have.been.calledOnce
        expect(scope.task.subject).to.be.equal("Alterada pela T·IA")

    it "evento de exclusão da própria tarefa não consulta", ->
        expectTaskReloaded("Apagada")

        emit({type: "delete", matches: "tasks.task", pk: 20})

        expect(mocks.rs.tasks.getByRef).not.to.have.been.called
        expect(scope.task.subject).to.be.equal("Tarefa")

    it "object:updated recarrega enquanto a tela está aberta e deixa de recarregar depois que o scope é destruído", ->
        mocks.rs.tasks.getByRef.reset()
        $rootScope.$broadcast("object:updated")
        $rootScope.$digest()
        expect(mocks.rs.tasks.getByRef).to.have.been.calledOnce

        scope.$destroy()
        mocks.rs.tasks.getByRef.reset()
        $rootScope.$broadcast("object:updated")
        $rootScope.$digest()
        expect(mocks.rs.tasks.getByRef).not.to.have.been.called
