local Player = {}

function Player.new(assets, larguraTela, alturaTela)
    local imagem = assets.images.jogador
    local tamanho = 64

    return {
        x = larguraTela / 2,
        y = alturaTela / 2,
        velocidade = 250,
        tamanho = tamanho,
        vidas = 3,
        tempoInvulneravel = 0,

        imagem = imagem,
        escala = tamanho / imagem:getWidth(),

        tiros = {},
        timerTiro = 0,
        intervaloTiro = 0.4
    }
end

function Player.reset(player, larguraTela, alturaTela)
    player.x = larguraTela / 2
    player.y = alturaTela / 2
    player.vidas = 3
    player.tempoInvulneravel = 0
    player.timerTiro = 0
    player.tiros = {}
end

function Player.update(player, dt, larguraTela, alturaTela, tiroRapidoAtivo)
    -- Movimento com WASD ou setas
    local dx = 0
    local dy = 0

    if love.keyboard.isDown("d", "right") then
        dx = dx + 1
    end
    if love.keyboard.isDown("a", "left") then
        dx = dx - 1
    end
    if love.keyboard.isDown("s", "down") then
        dy = dy + 1
    end
    if love.keyboard.isDown("w", "up") then
        dy = dy - 1
    end

    -- Normaliza o vetor para manter a mesma velocidade na diagonal
    local comprimento = math.sqrt(dx * dx + dy * dy)
    if comprimento > 0 then
        dx = dx / comprimento
        dy = dy / comprimento
    end

    player.x = player.x + dx * player.velocidade * dt
    player.y = player.y + dy * player.velocidade * dt

    -- Mantém o jogador dentro da janela
    local metade = player.tamanho / 2
    player.x = math.max(metade, math.min(larguraTela - metade, player.x))
    player.y = math.max(metade, math.min(alturaTela - metade, player.y))

    -- Atualiza a invulnerabilidade
    player.tempoInvulneravel = math.max(0, player.tempoInvulneravel - dt)

    -- Intervalo e velocidade dos tiros
    player.timerTiro = player.timerTiro - dt

    local intervaloAtual = tiroRapidoAtivo
        and player.intervaloTiro / 2
        or player.intervaloTiro

    local velocidadeTiro = tiroRapidoAtivo and 750 or 500

    -- Segurar o botão esquerdo do mouse dispara continuamente
    if love.mouse.isDown(1) and player.timerTiro <= 0 then
        player.timerTiro = intervaloAtual

        local mouseX, mouseY = love.mouse.getPosition()
        local angulo = math.atan2(mouseY - player.y, mouseX - player.x)

        table.insert(player.tiros, {
            x = player.x,
            y = player.y,
            dx = math.cos(angulo),
            dy = math.sin(angulo),
            angulo = angulo,
            velocidade = velocidadeTiro,
            tamanho = 32
        })
    end

    -- Move os tiros e remove os que saíram da tela
    for i = #player.tiros, 1, -1 do
        local tiro = player.tiros[i]

        tiro.x = tiro.x + tiro.dx * tiro.velocidade * dt
        tiro.y = tiro.y + tiro.dy * tiro.velocidade * dt

        if tiro.x < -50 or tiro.x > larguraTela + 50
        or tiro.y < -50 or tiro.y > alturaTela + 50 then
            table.remove(player.tiros, i)
        end
    end
end

function Player.draw(player, assets, timerTiroRapido, timerEscudo)
    local imagemTiro = assets.images.tiroJogador
    local centroTiroX = imagemTiro:getWidth() / 2
    local centroTiroY = imagemTiro:getHeight() / 2
    local escalaTiro = 32 / imagemTiro:getWidth()

    love.graphics.setColor(1, 1, 1, 1)

    for _, tiro in ipairs(player.tiros) do
        love.graphics.draw(
            imagemTiro,
            tiro.x,
            tiro.y,
            tiro.angulo,
            escalaTiro,
            escalaTiro,
            centroTiroX,
            centroTiroY
        )
    end

    -- Pisca enquanto está invulnerável
    if player.tempoInvulneravel > 0
    and math.floor(player.tempoInvulneravel * 10) % 2 == 0 then
        love.graphics.setColor(1, 1, 1, 0.3)
    else
        love.graphics.setColor(1, 1, 1, 1)
    end

    local centroJogadorX = player.imagem:getWidth() / 2
    local centroJogadorY = player.imagem:getHeight() / 2

    love.graphics.draw(
        player.imagem,
        player.x,
        player.y,
        0,
        player.escala,
        player.escala,
        centroJogadorX,
        centroJogadorY
    )

    -- Aura do tiro rápido
    if timerTiroRapido and timerTiroRapido > 0 then
        local alpha = 0.4 + math.sin(love.timer.getTime() * 12) * 0.25

        love.graphics.setColor(0.85, 0.4, 1, alpha)
        love.graphics.setLineWidth(2)
        love.graphics.circle("line", player.x, player.y, player.tamanho / 2 + 6)
        love.graphics.setLineWidth(1)
    end

    -- Escudo protetor
    if timerEscudo and timerEscudo > 0 then
        local pulso = 1 + math.sin(love.timer.getTime() * 6) * 0.05
        local raio = (player.tamanho / 1.7) * pulso
        local alphaBorda = 0.6 + math.sin(love.timer.getTime() * 8) * 0.3

        love.graphics.setColor(0.2, 0.7, 1, 0.22)
        love.graphics.circle("fill", player.x, player.y, raio)

        love.graphics.setColor(0.4, 0.9, 1, alphaBorda)
        love.graphics.setLineWidth(3)
        love.graphics.circle("line", player.x, player.y, raio)
        love.graphics.setLineWidth(1)
    end

    love.graphics.setColor(1, 1, 1, 1)
end

return Player