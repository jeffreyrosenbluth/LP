using Random, Distributions

numactions = 3
oppstrategy = [0.4, 0.3, 0.3];

function pos(x)
    x > 0.0 ? x : 0.0
end

function normalize(xs)
    total = sum(xs)
    n = length(xs)
    if total > 0
        return map(x -> x / total, xs)
    else
         return fill(1.0 / n, n)
    end
end

function regrets2strat(regrets)
    strategy = map(pos, regrets)
    normalize(strategy)
end

function action(strategy)
    d = Categorical(strategy)
    rand(d)
end

function utility(a, b)
    if a == b return 0 end
    if a == 1 && b == 3 return 1 end
    if b == 1 && a == 3 return -1 end
    a > b ? 1 : -1
end

function train(n, f1, f2)
    regrets = (zeros(numactions), zeros(numactions))
    strategys = (zeros(numactions), zeros(numactions))
    for _ in 1:n
        # Get regret-matched mixed-strategy actions
        strats = (f1(regrets[1]), f2(regrets[2]))
        strategys = strategys .+ strats
        actions = map(action, strats)
        # Accumulate action regrets
        for a in 1:numactions
            regrets[1][a] += utility(a, actions[2]) - utility(actions[1], actions[2])
            regrets[2][a] += -utility(actions[1], a) + utility(actions[2], actions[1])
        end
    end
    strats = map(regrets2strat, regrets)
    map(normalize, strategys .+ strats)
end
