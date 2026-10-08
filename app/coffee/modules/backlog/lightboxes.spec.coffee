###
# This source code is licensed under the terms of the
# GNU Affero General Public License found in the LICENSE file in
# the root directory of this source tree.
#
# Copyright (c) 2021-present Kaleidos INC
###

describe "tgLbCreateEditSprint", ->
    scope = compile = provide = templateCache = $q = $timeout = $model = null
    mocks = {}
    elm = null

    _mockRepo = ->
        mocks.repo = {
            create: sinon.stub()
            save: sinon.stub()
            remove: sinon.stub()
        }
        provide.value "$tgRepo", mocks.repo

    _mockConfirm = ->
        mocks.confirm = {
            notify: sinon.stub()
            askOnDelete: sinon.stub()
        }
        provide.value "$tgConfirm", mocks.confirm

    _mockResources = ->
        provide.value "$tgResources", {}

    _mockLightboxService = ->
        mocks.lightboxService = {
            open: sinon.stub()
            close: sinon.stub()
        }
        provide.value "lightboxService", mocks.lightboxService

    _mockLoading = ->
        mocks.loading = {finish: sinon.stub()}
        chain = {
            target: -> chain
            start: -> mocks.loading
        }
        provide.value "$tgLoading", -> chain

    _mockTranslate = ->
        mocks.translate = {instant: sinon.stub()}
        mocks.translate.instant.returnsArg(0)
        mocks.translate.instant.withArgs("COMMON.PICKERDATE.FORMAT").returns("YYYY-MM-DD")
        provide.value "$translate", mocks.translate
        provide.value "translateFilter", (value) -> value

    _mockProjectService = ->
        mocks.projectService = {
            project: Immutable.fromJS({my_permissions: []})
        }
        provide.value "tgProjectService", mocks.projectService

    _mocks = ->
        module ($provide) ->
            provide = $provide
            _mockRepo()
            _mockConfirm()
            _mockResources()
            _mockLightboxService()
            _mockLoading()
            _mockTranslate()
            _mockProjectService()
            return null

    _inject = ->
        inject ($rootScope, $compile, $templateCache, _$q_, _$timeout_, $tgModel) ->
            scope = $rootScope.$new()
            compile = $compile
            templateCache = $templateCache
            $q = _$q_
            $timeout = _$timeout_
            $model = $tgModel

    # The sprint lightbox is an include of backlog.html, so the real markup
    # is taken from there instead of being duplicated in the spec.
    createDirective = ->
        html = templateCache.get("backlog/backlog.html")
        lightbox = angular.element("<div>").append(html).find(".lightbox-sprint-add-edit")
        elm = compile(lightbox)(scope)
        angular.element(document.body).append(elm)
        scope.$digest()
        return elm

    openCreate = ->
        scope.$broadcast("sprintform:create", 1)
        $timeout.flush()
        scope.$digest()

    openEdit = (attrs) ->
        sprint = $model.make_model("milestones", attrs)
        scope.$broadcast("sprintform:edit", sprint)
        $timeout.flush()
        scope.$digest()

    fillDates = ->
        elm.find(".date-start").val("2026-09-01")
        elm.find(".date-end").val("2026-09-15")

    fillGoal = (goal) ->
        elm.find("textarea[name=goal]").val(goal).trigger("input")
        scope.$digest()

    submitForm = ->
        elm.find("form").trigger("submit")
        scope.$digest()

    saveButton = ->
        return elm.find("button[type=submit]")

    beforeEach ->
        module "templates"
        module "taigaBase"
        module "taigaBacklog"
        _mocks()
        _inject()
        createDirective()

    afterEach ->
        elm.remove() if elm
        elm = null

    describe "create sprint", ->
        beforeEach ->
            openCreate()
            scope.newSprint.name = "Sprint 1"
            scope.$digest()
            fillDates()

        it "shows the goal textarea and keeps save disabled while the goal is empty", ->
            expect(elm.find("textarea[name=goal]")).to.have.length(1)
            expect(elm.find(".sprint-goal-readonly")).to.have.length(0)
            expect(saveButton().prop("disabled")).to.be.true

            fillGoal("   ")
            expect(saveButton().prop("disabled")).to.be.true

        it "does not send the sprint when the goal is empty", ->
            submitForm()

            expect(mocks.repo.create.callCount).to.be.equal(0)
            expect(mocks.lightboxService.close.callCount).to.be.equal(0)

        it "enables save with a goal and sends it in the create payload", ->
            mocks.repo.create.returns($q.when({id: 5, name: "Sprint 1", goal: "# Meta"}))

            fillGoal("# Meta")
            expect(saveButton().prop("disabled")).to.be.false

            submitForm()

            expect(mocks.repo.create.callCount).to.be.equal(1)
            expect(mocks.repo.create.firstCall.args[0]).to.be.equal("milestones")
            payload = mocks.repo.create.firstCall.args[1]
            expect(payload.goal).to.be.equal("# Meta")
            expect(payload.name).to.be.equal("Sprint 1")
            expect(mocks.lightboxService.close.callCount).to.be.equal(1)

        it "keeps the modal open and shows the field error when the API refuses the goal", ->
            mocks.repo.create.returns($q.reject({goal: ["This field is required."]}))

            fillGoal("# Meta")
            submitForm()

            expect(mocks.repo.create.callCount).to.be.equal(1)
            expect(mocks.lightboxService.close.callCount).to.be.equal(0)
            expect(mocks.loading.finish.callCount).to.be.equal(1)
            errors = elm.find(".checksley-error-list li")
            expect(errors).to.have.length(1)
            expect(errors.text()).to.be.equal("This field is required.")

    describe "edit sprint", ->
        sprintAttrs = {
            id: 7
            project: 1
            name: "Sprint 1"
            estimated_start: "2026-09-01"
            estimated_finish: "2026-09-15"
            goal: "# Meta"
            version: 1
        }

        it "shows the goal read-only, without a textarea, and save is enabled", ->
            openEdit(sprintAttrs)

            expect(elm.find("textarea[name=goal]")).to.have.length(0)
            expect(elm.find(".sprint-goal-readonly")).to.have.length(1)
            expect(elm.find(".sprint-goal-readonly .wysiwyg")).to.have.length(1)
            expect(elm.find(".sprint-goal-readonly-empty")).to.have.length(0)
            expect(saveButton().prop("disabled")).to.be.false

        it "shows the empty message for a sprint without goal and still lets save", ->
            openEdit(_.extend({}, sprintAttrs, {goal: ""}))

            expect(elm.find(".sprint-goal-readonly .wysiwyg")).to.have.length(0)
            expect(elm.find(".sprint-goal-readonly-empty")).to.have.length(1)
            expect(saveButton().prop("disabled")).to.be.false

        it "does not send the goal in the edit payload", ->
            openEdit(sprintAttrs)
            mocks.repo.save.returns($q.when(_.extend({}, sprintAttrs, {name: "Sprint 2"})))

            scope.newSprint.name = "Sprint 2"
            scope.$digest()
            fillDates()
            submitForm()

            expect(mocks.repo.save.callCount).to.be.equal(1)
            saved = mocks.repo.save.firstCall.args[0]
            expect(saved.isAttributeModified("goal")).to.be.false
            expect(saved.getAttrs(true)).to.not.have.property("goal")
            expect(saved.getAttrs(true).name).to.be.equal("Sprint 2")
            expect(mocks.lightboxService.close.callCount).to.be.equal(1)
