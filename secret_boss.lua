local SecretBoss = {}

-- Ajuste aqui a resistência, tamanho, velocidade e ritmo das rajadas do chefe secreto.
local CONFIGURACAO = {
    tamanho = 96,
    vida = 60,
    velocidadeEntrada = 500,
    velocidadeLateral = 390,
    velocidadePausa = 175,
    velocidadeRetirada = 540,
    quantidadeTiros = 3,
    intervaloTiros = 0.32,
    velocidadeTiros = 360,
    tempoPausa = 1.8,
    tempoSumido = 0.8,
    tempoIntro = 2.5
}

local BORDAS_SAIDA = { "right", "bottom", "left", "top" }
local BORDA_OPPOSTA = {
    right = "left",
    bottom = "top",
    left = "right",
    top = "bottom"
}

local function colisaoCirculo(x1, y1, r1, x2, y2, r2)
    local dx = x1 - x2
    local dy = y1 - y2
    return dx * dx + dy * dy < (r1 + r2) * (r1 + r2)
end

local function tocarMusicaDuelo(audio)
    if not audio then return end
    if audio.musicaMenu then audio.musicaMenu:stop() end
    if audio.musicaFundo then audio.musicaFundo:stop() end
    if audio.musicaBatalha then audio.musicaBatalha:stop() end
    if audio.musicaBoss2 then audio.musicaBoss2:stop() end
    if audio.musicaBatalha then audio.musicaBatalha:play() end
end

local function voltarMusicaFundo(audio)
    if not audio then return end
    if audio.musicaBatalha then audio.musicaBatalha:stop() end
    if audio.musicaBoss2 then audio.musicaBoss2:stop() end
    if audio.musicaFundo then audio.musicaFundo:play() end
end

local function moverAte(boss, alvoX, alvoY, velocidade, dt)
    local dx = alvoX - boss.x
    local dy = alvoY - boss.y
    local distancia = math.sqrt(dx * dx + dy * dy)

    if distancia <= velocidade * dt or distancia == 0 then
        boss.x = alvoX
        boss.y = alvoY
        return true
    end

    boss.x = boss.x + dx / distancia * velocidade * dt
    boss.y = boss.y + dy / distancia * velocidade * dt
    return false
end

local function coordenadasEntrada(borda, w, h, tamanho)
    if borda == "left" then
        return -tamanho, love.math.random(100, h - 100), tamanho + 35,
            love.math.random(100, h - 100)
    elseif borda == "right" then
        return w + tamanho, love.math.random(100, h - 100),
            w - tamanho - 35, love.math.random(100, h - 100)
    elseif borda == "bottom" then
        return love.math.random(100, w - 100), h + tamanho,
            love.math.random(100, w - 100), h - tamanho - 35
    end

    return love.math.random(100, w - 100), -tamanho,
        love.math.random(100, w - 100), tamanho + 35
end

local function prepararEntrada(boss, borda, w, h)
    boss.bordaEntrada = borda
    boss.x, boss.y, boss.alvoX, boss.alvoY =
        coordenadasEntrada(borda, w, h, boss.tamanho)
    boss.direcao = love.math.random(0, 1) == 0 and -1 or 1
    boss.fase = "entrada"
end

local function iniciarRetirada(boss, w, h)
    boss.bordaSaida = BORDAS_SAIDA[boss.proximaBordaSaida]
    boss.proximaBordaSaida = boss.proximaBordaSaida % #BORDAS_SAIDA + 1

    if boss.bordaSaida == "right" then
        boss.alvoX, boss.alvoY = w + boss.tamanho, boss.y
    elseif boss.bordaSaida == "left" then
        boss.alvoX, boss.alvoY = -boss.tamanho, boss.y
    elseif boss.bordaSaida == "bottom" then
        boss.alvoX, boss.alvoY = boss.x, h + boss.tamanho
    else
        boss.alvoX, boss.alvoY = boss.x, -boss.tamanho
    end

    boss.fase = "retirada"
end

function SecretBoss.new()
    return {
        boss = nil,
        bossEntrando = false,
        timerIntro = 0,
        tirosInimigos = {}
    }
end

function SecretBoss.reset(state)
    state.boss = nil
    state.bossEntrando = false
    state.timerIntro = 0
    state.tirosInimigos = {}
end

function SecretBoss.start(state, player, w, h, audio)
    local tamanho = CONFIGURACAO.tamanho
    state.boss = {
        tipo = 3,
        nome = "CHEFE SECRETO",
        x = w / 2,
        y = -tamanho,
        alvoX = w / 2,
        alvoY = math.max(100, h * 0.22),
        tamanho = tamanho,
        vida = CONFIGURACAO.vida,
        vidaMaxima = CONFIGURACAO.vida,
        timerTiro = 0.7,
        timerTiroRapido = 0,
        timerEscudo = 0,
        fase = "intro",
        tirosNaRajada = 0,
        timerFase = 0,
        direcao = 1,
        tempoMovimento = 0,
        proximaBordaSaida = 1,
        visivel = true
    }
    state.bossEntrando = true
    state.timerIntro = CONFIGURACAO.tempoIntro
    state.tirosInimigos = {}
    tocarMusicaDuelo(audio)
end

function SecretBoss.isActive(state)
    return state and state.boss ~= nil
end

function SecretBoss.collectItem(state, tipo)
    local boss = state.boss
    if not boss then return end
    if tipo == "vida" then
        boss.vida = math.min(boss.vidaMaxima, boss.vida + 1)
    elseif tipo == "tiro_rapido" then
        boss.timerTiroRapido = 10
    elseif tipo == "escudo" then
        boss.timerEscudo = 10
    end
end

function SecretBoss.update(state, dt, player, w, h, escudoPlayerAtivo, item)
    local boss = state.boss
    if not boss then return end

    boss.timerTiroRapido = math.max(0, boss.timerTiroRapido - dt)
    boss.timerEscudo = math.max(0, boss.timerEscudo - dt)
    boss.tempoMovimento = boss.tempoMovimento + dt

    if boss.fase == "intro" then
        state.timerIntro = math.max(0, state.timerIntro - dt)
        local chegou = moverAte(
            boss,
            boss.alvoX,
            boss.alvoY,
            CONFIGURACAO.velocidadeEntrada,
            dt
        )

        if chegou or state.timerIntro <= 0 then
            boss.fase = "ataque"
            boss.tirosNaRajada = 0
            boss.timerTiro = 0.3
            state.bossEntrando = false
        end
    elseif boss.fase == "ataque" or boss.fase == "pausa" then
        local margem = boss.tamanho / 2 + 20
        local velocidade = boss.fase == "ataque"
            and CONFIGURACAO.velocidadeLateral
            or CONFIGURACAO.velocidadePausa

        boss.x = boss.x + boss.direcao * velocidade * dt
        if boss.x >= w - margem then
            boss.x = w - margem
            boss.direcao = -1
        elseif boss.x <= margem then
            boss.x = margem
            boss.direcao = 1
        end
        boss.y = boss.alvoY + math.sin(boss.tempoMovimento * 5) * 24

        if boss.fase == "ataque" then
            boss.timerTiro = boss.timerTiro - dt
            if boss.timerTiro <= 0 then
                local angulo = math.atan2(
                    player.y - boss.y,
                    player.x - boss.x
                )
                local velocidadeTiro = boss.timerTiroRapido > 0
                    and CONFIGURACAO.velocidadeTiros * 1.2
                    or CONFIGURACAO.velocidadeTiros

                table.insert(state.tirosInimigos, {
                    x = boss.x,
                    y = boss.y,
                    dx = math.cos(angulo),
                    dy = math.sin(angulo),
                    angulo = angulo,
                    velocidade = velocidadeTiro,
                    tamanho = 32
                })

                boss.tirosNaRajada = boss.tirosNaRajada + 1
                boss.timerTiro = CONFIGURACAO.intervaloTiros

                if boss.tirosNaRajada >= CONFIGURACAO.quantidadeTiros then
                    boss.fase = "pausa"
                    boss.timerFase = CONFIGURACAO.tempoPausa
                end
            end
        else
            boss.timerFase = boss.timerFase - dt
            if boss.timerFase <= 0 then
                iniciarRetirada(boss, w, h)
            end
        end
    elseif boss.fase == "retirada" then
        if moverAte(
            boss,
            boss.alvoX,
            boss.alvoY,
            CONFIGURACAO.velocidadeRetirada,
            dt
        ) then
            boss.fase = "sumido"
            boss.timerFase = CONFIGURACAO.tempoSumido
            boss.visivel = false
        end
    elseif boss.fase == "sumido" then
        boss.timerFase = boss.timerFase - dt
        if boss.timerFase <= 0 then
            prepararEntrada(
                boss,
                BORDA_OPPOSTA[boss.bordaSaida],
                w,
                h
            )
            boss.visivel = true
            state.bossEntrando = true
        end
    elseif boss.fase == "entrada" then
        local chegou = moverAte(
            boss,
            boss.alvoX,
            boss.alvoY,
            CONFIGURACAO.velocidadeEntrada,
            dt
        )

        if chegou then
            boss.fase = "ataque"
            boss.tirosNaRajada = 0
            boss.timerTiro = 0.3
            state.bossEntrando = false
        end
    end

    for i = #state.tirosInimigos, 1, -1 do
        local tiro = state.tirosInimigos[i]
        tiro.x = tiro.x + tiro.dx * tiro.velocidade * dt
        tiro.y = tiro.y + tiro.dy * tiro.velocidade * dt

        local acertou = colisaoCirculo(
            tiro.x,
            tiro.y,
            tiro.tamanho / 2.2,
            player.x,
            player.y,
            player.tamanho / 2.2
        )
        local fora = tiro.x < -50 or tiro.x > w + 50
            or tiro.y < -50 or tiro.y > h + 50

        if acertou then
            if not escudoPlayerAtivo and player.tempoInvulneravel <= 0 then
                player.vidas = player.vidas - 1
                player.tempoInvulneravel = 1
            end
            table.remove(state.tirosInimigos, i)
        elseif fora then
            table.remove(state.tirosInimigos, i)
        end
    end
end

function SecretBoss.handlePlayerBullets(state, player, audio)
    local boss = state.boss
    if not boss or (boss.fase ~= "ataque" and boss.fase ~= "pausa") then
        return false
    end

    for i = #player.tiros, 1, -1 do
        local tiro = player.tiros[i]
        if colisaoCirculo(
            tiro.x,
            tiro.y,
            (tiro.tamanho or 32) / 2,
            boss.x,
            boss.y,
            boss.tamanho / 2.2
        ) then
            table.remove(player.tiros, i)
            if boss.timerEscudo <= 0 then
                boss.vida = boss.vida - (tiro.dano or 1)
                if boss.vida <= 0 then
                    state.boss = nil
                    state.bossEntrando = false
                    state.tirosInimigos = {}
                    voltarMusicaFundo(audio)
                    return true
                end
            end
        end
    end
    return false
end

function SecretBoss.draw(state, assets)
    local tiro = assets.images.tiroJogador
    local escala = 32 / tiro:getWidth()
    for _, bala in ipairs(state.tirosInimigos) do
        love.graphics.setColor(1, 0.35, 0.35, 1)
        love.graphics.draw(
            tiro,
            bala.x,
            bala.y,
            bala.angulo,
            escala,
            escala,
            tiro:getWidth() / 2,
            tiro:getHeight() / 2
        )
    end

    local boss = state.boss
    if boss and boss.visivel then
        local imagem = assets.images.bossSecreto
        local escalaBoss = boss.tamanho / imagem:getWidth()
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(
            imagem,
            boss.x,
            boss.y,
            0,
            escalaBoss,
            escalaBoss,
            imagem:getWidth() / 2,
            imagem:getHeight() / 2
        )
        if boss.timerEscudo > 0 then
            love.graphics.setColor(0.2, 0.8, 1, 0.5)
            love.graphics.circle("line", boss.x, boss.y, boss.tamanho * 0.7)
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

return SecretBoss
