local Enemies = {}

local TAMANHO_INIMIGO = 48

local function colisaoCirculo(x1, y1, raio1, x2, y2, raio2)
    local dx = x1 - x2
    local dy = y1 - y2

    return dx * dx + dy * dy < (raio1 + raio2) * (raio1 + raio2)
end

function Enemies.new()
    return {
        lista = {},
        timerSpawn = 0.5
    }
end

function Enemies.reset(enemies)
    enemies.lista = {}
    enemies.timerSpawn = 0.5
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
    escudoAtivo
)
    local pontosGanhos = 0

    -- Os inimigos comuns ficam parados durante a luta contra um chefe.
    if bossAtivo then
        return pontosGanhos
    end

    -- Cria um novo inimigo quando o temporizador termina.
    enemies.timerSpawn = enemies.timerSpawn - dt

    if enemies.timerSpawn <= 0 then
        local intervaloSpawn = math.max(0.6, 1.2 - tempoPartida * 0.008)
        enemies.timerSpawn = intervaloSpawn

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

        local tipo = 1
        local vida = 1
        local tamanho = TAMANHO_INIMIGO

        if primeiroBossDerrotado and love.math.random() < 0.45 then
            tipo = 2
            vida = 2
        end

        local bonusVelocidade = math.min(110, tempoPartida * 2)
        local velocidadeMinima = 80 + bonusVelocidade
        local velocidadeMaxima = 130 + bonusVelocidade

        table.insert(enemies.lista, {
            x = x,
            y = y,
            tipo = tipo,
            vida = vida,
            tamanho = tamanho,
            velocidade = love.math.random(
                velocidadeMinima,
                velocidadeMaxima
            )
        })
    end

    -- Move os inimigos em direção ao jogador e verifica contato.
    for i = #enemies.lista, 1, -1 do
        local enemy = enemies.lista[i]
        local angulo = math.atan2(player.y - enemy.y, player.x - enemy.x)

        enemy.x = enemy.x + math.cos(angulo) * enemy.velocidade * dt
        enemy.y = enemy.y + math.sin(angulo) * enemy.velocidade * dt

        local encostouNoJogador = colisaoCirculo(
            enemy.x,
            enemy.y,
            enemy.tamanho / 2.2,
            player.x,
            player.y,
            player.tamanho / 2.2
        )

        if encostouNoJogador then
            if escudoAtivo then
                pontosGanhos = pontosGanhos + (enemy.tipo == 2 and 20 or 10)
            elseif player.tempoInvulneravel <= 0 then
                player.vidas = player.vidas - 1
                player.tempoInvulneravel = 1.0
            end

            -- Remove o inimigo ao contato, inclusive se o jogador estava invulnerável.
            table.remove(enemies.lista, i)
        end
    end

    return pontosGanhos
end

function Enemies.handlePlayerBullets(enemies, player)
    local pontosGanhos = 0

    -- Percorre as duas listas de trás para frente porque remove itens.
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
                enemy.vida = enemy.vida - 1

                if enemy.vida <= 0 then
                    pontosGanhos = pontosGanhos + (enemy.tipo == 2 and 20 or 10)
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
        local imagem

        if enemy.tipo == 2 then
            imagem = assets.images.inimigo2
        else
            imagem = assets.images.inimigo
        end

        local escala = enemy.tamanho / imagem:getWidth()
        local centroX = imagem:getWidth() / 2
        local centroY = imagem:getHeight() / 2

        love.graphics.draw(
            imagem,
            enemy.x,
            enemy.y,
            0,
            escala,
            escala,
            centroX,
            centroY
        )
    end

    love.graphics.setColor(1, 1, 1, 1)
end

return Enemies