local Enemies = {}

-- Ajuste vida, tamanho e faixa de velocidade de cada inimigo nestas entradas.
local TIPOS_INIMIGO = {
    -- Inimigo 1: inimigo básico, equilibrado em velocidade e resistência.
    [1] = { vida = 1, tamanho = 44, velocidadeMinima = 65, velocidadeMaxima = 90 },
    -- Inimigo 2: mais resistente e um pouco mais lento.
    [2] = { vida = 2, tamanho = 50, velocidadeMinima = 58, velocidadeMaxima = 82 },
    -- Inimigo 3: rápido, mas pode ser eliminado com poucos tiros.
    [3] = { vida = 2, tamanho = 46, velocidadeMinima = 105, velocidadeMaxima = 135 },
    -- Inimigo 4: veloz ao atravessar a cena; valores daqui são a velocidade-base.
    [4] = { vida = 4, tamanho = 60, velocidadeMinima = 48, velocidadeMaxima = 68 }
}

local function colisaoCirculo(x1, y1, raio1, x2, y2, raio2)
    local dx = x1 - x2
    local dy = y1 - y2

    return dx * dx + dy * dy < (raio1 + raio2) * (raio1 + raio2)
end

local function sortearTipo(primeiroBossDerrotado, chefesDerrotados)
    local sorteio = love.math.random()

    -- Ajuste estes limites para mudar a chance de cada tipo nos estágios avançados.
    if chefesDerrotados >= 3 then
        if sorteio < 0.2 then return 1 end
        if sorteio < 0.4 then return 2 end
        if sorteio < 0.7 then return 3 end
        return 4
    elseif chefesDerrotados >= 2 then
        if sorteio < 0.4 then return 1 end
        if sorteio < 0.7 then return 2 end
        return 3
    elseif primeiroBossDerrotado then
        return sorteio < 0.65 and 1 or 2
    end

    return 1
end

local function criarInimigo(
    enemies,
    tipo,
    x,
    y,
    tempoPartida,
    larguraTela,
    alturaTela
)
    local dados = TIPOS_INIMIGO[tipo]
    local bonusVelocidade = math.min(25, tempoPartida * 0.2)
    local velocidade = love.math.random(
        dados.velocidadeMinima,
        dados.velocidadeMaxima
    ) + bonusVelocidade
    local enemy = {
        x = x,
        y = y,
        tipo = tipo,
        vida = dados.vida,
        tamanho = dados.tamanho,
        velocidade = velocidade
    }

    if tipo == 4 then
        -- Enemy 4 sempre cruza a cena em linha reta; ajuste o multiplicador aqui.
        enemy.velocidade = enemy.velocidade * 3
        local alvoX, alvoY

        if y < 0 then
            alvoX, alvoY = love.math.random(0, larguraTela), alturaTela + 40
        elseif y > alturaTela then
            alvoX, alvoY = love.math.random(0, larguraTela), -40
        elseif x < 0 then
            alvoX, alvoY = larguraTela + 40, love.math.random(0, alturaTela)
        else
            alvoX, alvoY = -40, love.math.random(0, alturaTela)
        end

        local dx = alvoX - x
        local dy = alvoY - y
        local distancia = math.sqrt(dx * dx + dy * dy)
        enemy.dx = dx / distancia
        enemy.dy = dy / distancia
    end

    table.insert(enemies.lista, enemy)
end

function Enemies.new()
    return {
        lista = {},
        timerSpawn = 0.6,
        misseisTeleguiados = {},
        timerPoderTeleguiado = 0,
        timerLancamentoTeleguiado = 0
    }
end

function Enemies.reset(enemies)
    enemies.lista = {}
    enemies.timerSpawn = 0.6
    enemies.misseisTeleguiados = {}
    enemies.timerPoderTeleguiado = 0
    enemies.timerLancamentoTeleguiado = 0
end

function Enemies.debugSpawn(enemies, tipo, larguraTela, alturaTela)
    local borda = love.math.random(1, 4)
    local x, y

    if borda == 1 then
        x = love.math.random(0, larguraTela)
        y = -40
    elseif borda == 2 then
        x = love.math.random(0, larguraTela)
        y = alturaTela + 40
    elseif borda == 3 then
        x = -40
        y = love.math.random(0, alturaTela)
    else
        x = larguraTela + 40
        y = love.math.random(0, alturaTela)
    end

    criarInimigo(enemies, tipo, x, y, 0, larguraTela, alturaTela)
end

function Enemies.update(
    enemies,
    dt,
    player,
    tempoPartida,
    larguraTela,
    alturaTela,
    bossAtivo,
    primeiroBossDerrotado,
    escudoAtivo,
    chefesDerrotados
)
    local pontosGanhos = 0

    if bossAtivo then
        return pontosGanhos
    end

    enemies.timerSpawn = enemies.timerSpawn - dt

    if enemies.timerSpawn <= 0 then
        -- Intervalo mínimo e ritmo de surgimento dos inimigos comuns.
        enemies.timerSpawn = math.max(0.85, 1.4 - tempoPartida * 0.003)

        local borda = love.math.random(1, 4)
        local x, y

        if borda == 1 then
            x = love.math.random(0, larguraTela)
            y = -40
        elseif borda == 2 then
            x = love.math.random(0, larguraTela)
            y = alturaTela + 40
        elseif borda == 3 then
            x = -40
            y = love.math.random(0, alturaTela)
        else
            x = larguraTela + 40
            y = love.math.random(0, alturaTela)
        end

        local tipo = sortearTipo(
            primeiroBossDerrotado,
            chefesDerrotados or (primeiroBossDerrotado and 1 or 0)
        )
        criarInimigo(
            enemies,
            tipo,
            x,
            y,
            tempoPartida,
            larguraTela,
            alturaTela
        )
    end

    for i = #enemies.lista, 1, -1 do
        local enemy = enemies.lista[i]
        if enemy.tipo == 4 then
            enemy.x = enemy.x + enemy.dx * enemy.velocidade * dt
            enemy.y = enemy.y + enemy.dy * enemy.velocidade * dt
        else
            local angulo = math.atan2(player.y - enemy.y, player.x - enemy.x)
            enemy.x = enemy.x + math.cos(angulo) * enemy.velocidade * dt
            enemy.y = enemy.y + math.sin(angulo) * enemy.velocidade * dt
        end

        local encostouNoJogador = colisaoCirculo(
            enemy.x,
            enemy.y,
            enemy.tamanho / 2.2,
            player.x,
            player.y,
            player.tamanho / 2.2
        )

        local saiuDaTela = enemy.x < -enemy.tamanho
            or enemy.x > larguraTela + enemy.tamanho
            or enemy.y < -enemy.tamanho
            or enemy.y > alturaTela + enemy.tamanho

        if encostouNoJogador then
            if escudoAtivo then
                pontosGanhos = pontosGanhos + enemy.tipo * 10
            elseif player.tempoInvulneravel <= 0 then
                player.vidas = player.vidas - 1
                player.tempoInvulneravel = 1.0
            end

            table.remove(enemies.lista, i)
        elseif saiuDaTela then
            table.remove(enemies.lista, i)
        end
    end

    return pontosGanhos
end

function Enemies.activateGuidedPower(enemies)
    -- Duração do poder e intervalo entre os mísseis teleguiados.
    enemies.timerPoderTeleguiado = 8
    enemies.timerLancamentoTeleguiado = 0
end

function Enemies.updateGuidedMissiles(
    enemies,
    dt,
    player,
    larguraTela,
    alturaTela,
    bossAtivo,
    alvosBoss
)
    enemies.timerPoderTeleguiado = math.max(
        0,
        enemies.timerPoderTeleguiado - dt
    )

    local alvos = {}
    if bossAtivo then
        for _, boss in ipairs(alvosBoss or {}) do
            table.insert(alvos, boss)
        end
    else
        for _, enemy in ipairs(enemies.lista) do
            table.insert(alvos, {
                x = enemy.x,
                y = enemy.y,
                tamanho = enemy.tamanho,
                inimigo = enemy
            })
        end
    end

    if enemies.timerPoderTeleguiado > 0 then
        enemies.timerLancamentoTeleguiado =
            enemies.timerLancamentoTeleguiado - dt

        if enemies.timerLancamentoTeleguiado <= 0
        and #alvos > 0 then
            table.insert(enemies.misseisTeleguiados, {
                x = player.x,
                y = player.y,
                -- Velocidade e tamanho dos mísseis do power-up teleguiado.
                velocidade = 420,
                tamanho = 28
            })
            enemies.timerLancamentoTeleguiado = 1
        end
    end

    local pontosGanhos = 0

    for missileIndex = #enemies.misseisTeleguiados, 1, -1 do
        local missile = enemies.misseisTeleguiados[missileIndex]
        local alvo, distanciaMinima

        for _, target in ipairs(alvos) do
            local dx = target.x - missile.x
            local dy = target.y - missile.y
            local distancia = dx * dx + dy * dy

            if not distanciaMinima or distancia < distanciaMinima then
                alvo = target
                distanciaMinima = distancia
            end
        end

        if alvo then
            local dx = alvo.x - missile.x
            local dy = alvo.y - missile.y
            local distancia = math.sqrt(dx * dx + dy * dy)
            local passo = missile.velocidade * dt

            if distancia <= passo + alvo.tamanho / 2 then
                if alvo.inimigo then
                    for enemyIndex = #enemies.lista, 1, -1 do
                        if enemies.lista[enemyIndex] == alvo.inimigo then
                            pontosGanhos = pontosGanhos
                                + alvo.inimigo.tipo * 10
                            table.remove(enemies.lista, enemyIndex)
                            break
                        end
                    end
                else
                    -- Dano por míssil; o fluxo normal do boss aplica escudos e vulnerabilidade.
                    table.insert(player.tiros, {
                        x = alvo.x,
                        y = alvo.y,
                        tamanho = missile.tamanho,
                        dano = 2,
                        guiado = true
                    })
                end
                table.remove(enemies.misseisTeleguiados, missileIndex)
            else
                missile.x = missile.x + dx / distancia * passo
                missile.y = missile.y + dy / distancia * passo
            end
        elseif missile.x < -50 or missile.x > larguraTela + 50
        or missile.y < -50 or missile.y > alturaTela + 50 then
            table.remove(enemies.misseisTeleguiados, missileIndex)
        end
    end

    return pontosGanhos
end

function Enemies.handlePlayerBullets(enemies, player)
    local pontosGanhos = 0

    for tiroIndex = #player.tiros, 1, -1 do
        local tiro = player.tiros[tiroIndex]

        for enemyIndex = #enemies.lista, 1, -1 do
            local enemy = enemies.lista[enemyIndex]
            local acertou = colisaoCirculo(
                tiro.x,
                tiro.y,
                (tiro.tamanho or 32) / 2,
                enemy.x,
                enemy.y,
                enemy.tamanho / 2
            )

            if acertou then
                table.remove(player.tiros, tiroIndex)
                enemy.vida = enemy.vida - (tiro.dano or 1)

                if enemy.vida <= 0 then
                    pontosGanhos = pontosGanhos + enemy.tipo * 10
                    table.remove(enemies.lista, enemyIndex)
                end

                break
            end
        end
    end

    return pontosGanhos
end

function Enemies.draw(enemies, assets)
    love.graphics.setColor(1, 1, 1, 1)

    for _, enemy in ipairs(enemies.lista) do
        local imagem = assets.images["inimigo" .. enemy.tipo]
            or assets.images.inimigo
        local escala = enemy.tamanho / imagem:getWidth()

        love.graphics.draw(
            imagem,
            enemy.x,
            enemy.y,
            0,
            escala,
            escala,
            imagem:getWidth() / 2,
            imagem:getHeight() / 2
        )
    end

    local imagemMissil = assets.images.powerupTeleguiado
    local escalaMissil = 28 / imagemMissil:getWidth()

    for _, missile in ipairs(enemies.misseisTeleguiados) do
        love.graphics.draw(
            imagemMissil,
            missile.x,
            missile.y,
            0,
            escalaMissil,
            escalaMissil,
            imagemMissil:getWidth() / 2,
            imagemMissil:getHeight() / 2
        )
    end

    love.graphics.setColor(1, 1, 1, 1)
end

return Enemies
