###
# This source code is licensed under the terms of the
# GNU Affero General Public License found in the LICENSE file in
# the root directory of this source tree.
#
# Copyright (c) 2021-present Kaleidos INC
###

describe "$tgSprintsResourcesProvider", ->
    sprints = $q = $rootScope = null
    mocks = {}

    _mockRepo = ->
        mocks.repo = {
            queryMany: sinon.stub()
        }

    _mockModel = ->
        mocks.model = {
            make_model: sinon.stub().returnsArg(1)
        }

    _mockHttp = ->
        mocks.http = {
            post: sinon.stub()
        }

    _mockUrls = ->
        mocks.urls = {
            resolve: sinon.stub()
            update: sinon.stub()
        }

    _mocks = ->
        module ($provide) ->
            _mockRepo()
            _mockModel()
            _mockHttp()
            _mockUrls()
            $provide.value "$tgRepo", mocks.repo
            $provide.value "$tgModel", mocks.model
            $provide.value "$tgStorage", {}
            $provide.value "$tgHttp", mocks.http
            $provide.value "$tgUrls", mocks.urls
            # Required by sibling resource providers registered in the same module
            $provide.value "$tgAuth", {}
            $provide.value "$tgConfig", {}
            $provide.value "$translate", {}
            return null

    _inject = ->
        inject (_$q_, _$rootScope_, $tgSprintsResourcesProvider) ->
            $q = _$q_
            $rootScope = _$rootScope_
            instance = {}
            $tgSprintsResourcesProvider(instance)
            sprints = instance.sprints

    headersFrom = (values) ->
        return (name) -> values[name]

    milestone = (attrs) ->
        return _.extend({_attrs: {}, user_stories: []}, attrs)

    beforeEach ->
        module "taigaResources"
        _mocks()
        _inject()

    describe "list", ->
        it "reads the closed sprints without result counter from the response headers", ->
            headers = headersFrom({
                "Taiga-Info-Total-Closed-Milestones": "3"
                "Taiga-Info-Total-Opened-Milestones": "1"
                "Taiga-Info-Total-Closed-Milestones-Without-Result": "2"
            })
            mocks.repo.queryMany.withArgs("milestones", {project: 1, closed: false}, {}, true)
                .returns($q.resolve([[milestone({id: 10})], headers]))

            result = null
            sprints.list(1, {closed: false}).then (data) -> result = data
            $rootScope.$digest()

            expect(result.closed).to.be.equal(3)
            expect(result.open).to.be.equal(1)
            expect(result.closedWithoutResult).to.be.equal(2)
            expect(result.milestones).to.have.length(1)

        it "returns zero closed sprints without result when the header is absent", ->
            headers = headersFrom({
                "Taiga-Info-Total-Closed-Milestones": "3"
                "Taiga-Info-Total-Opened-Milestones": "1"
            })
            mocks.repo.queryMany.returns($q.resolve([[], headers]))

            result = null
            sprints.list(1).then (data) -> result = data
            $rootScope.$digest()

            expect(result.closedWithoutResult).to.be.equal(0)
