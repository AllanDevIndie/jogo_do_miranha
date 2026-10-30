if os.getenv("LOCAL_LUA_DEBUGGER_VSCODE") == "1" then
    require("lldebugger").start()
end

-- Funções auxiliares
local function pontoNoRetangulo(px, py, rx, ry, rw, rh)
    return px >= rx and px <= rx + rw and py >= ry and py <= ry + rh
end

local function colisaoCirculo(x1, y1, r1, x2, y2, r2)
    local dx = x1 - x2
    local dy = y1 - y2
    return (dx * dx + dy * dy) < ((r1 + r2) * (r1 + r2))
end

-- Variáveis de controle do jogo
local estado = "menu"
local pontos = 0
local tiros = {}
local inimigos = {}
local timerSpawn = 0
local tempoPartida = 0 -- Contador de tempo da partida em segundos

-- Sistema dos Chefões (Boss 1 e Boss 2 - Cthulhu)
local boss = nil
local bossJaApareceu = false
local bossEntrando = false
local timerIntroBoss = 0
local boss1Derrotado = false
local boss2JaApareceu = false
local timerSpawnBoss2 = -1
local boss2Derrotado = false
local tirosInimigos = {}

-- Sistema do Coração de Cura (heart.png)
local coracao = nil
local timerSpawnCoracao = 30 -- Surge a cada 30 segundos

-- Sistema de Power-ups Randômicos (Tiro Rápido, Escudo, etc.)
local powerup = nil
local timerSpawnPowerup = 35 -- Surge a cada 35 segundos
local timerTiroRapidoAtivo = 0 -- Duração de 10s quando coletado
local timerEscudoAtivo = 0 -- Imunidade a danos por 10s quando coletado
local tiposPowerup = {} -- Lista configurada no love.load para fácil adição de novos itens

-- Sistema de disparo contínuo do jogador
local timerTiro = 0
local intervaloTiro = 0.4 -- Intervalo em segundos entre cada tiro do herói

local function reiniciarJogo()
    estado = "jogando"
    pontos = 0
    tempoPartida = 0
    tiros = {}
    inimigos = {}
    tirosInimigos = {}
    boss = nil
    bossJaApareceu = false
    bossEntrando = false
    timerIntroBoss = 0
    boss1Derrotado = false
    boss2JaApareceu = false
    timerSpawnBoss2 = -1
    boss2Derrotado = false
    coracao = nil
    timerSpawnCoracao = 30
    powerup = nil
    timerSpawnPowerup = 35
    timerTiroRapidoAtivo = 0
    timerEscudoAtivo = 0
    timerSpawn = 0.5
    timerTiro = 0
    jogador.vidas = 3
    jogador.tempoInvulneravel = 0
    jogador.x = love.graphics.getWidth() / 2
    jogador.y = love.graphics.getHeight() / 2

    -- Reseta as músicas
    if musicaBatalha and musicaBatalha:isPlaying() then
        musicaBatalha:stop()
    end
    if musicaFundo then
        musicaFundo:stop()
        musicaFundo:play()
    end
end

function love.load()
    -- Posição do texto animado do menu
    x = 0
    velocidadeTexto = 50

    -- Configuração do botão do menu
    botao = {
        largura = 200,
        altura = 50,
        texto = "Iniciar Jogo"
    }
    botao.x = (love.graphics.getWidth() - botao.largura) / 2
    botao.y = (love.graphics.getHeight() / 2) + 60

    -- 1. JOGADOR (SUPERHERO)
    jogador = {
        x = love.graphics.getWidth() / 2,
        y = love.graphics.getHeight() / 2,
        velocidade = 250,
        tamanho = 64,
        vidas = 3,
        tempoInvulneravel = 0,
        imagem = love.graphics.newImage("image/superhero.png")
    }
    jogador.escala = jogador.tamanho / jogador.imagem:getWidth()

    -- 2. PODER / TIRO DO JOGADOR
    poderImg = love.graphics.newImage("image/power.png")
    poderTamanho = 32
    poderEscala = poderTamanho / poderImg:getWidth()

    -- 3. INIMIGO NORMAL
    inimigoImg = love.graphics.newImage("image/enemy.png")
    inimigoTamanho = 48
    inimigoEscala = inimigoTamanho / inimigoImg:getWidth()

    -- 3b. INIMIGO 2 (Pink Fire Skull - surge após derrotar o Boss 1, requer 2 tiros)
    enemy2Img = love.graphics.newImage("image/enemy2.png")
    inimigo2Tamanho = 48
    inimigo2Escala = inimigo2Tamanho / enemy2Img:getWidth()

    -- 4. BOSS 1 (CHEFÃO) - Dobro do tamanho dos inimigos normais (48 * 2 = 96)
    bossImg = love.graphics.newImage("image/boss.png")
    bossTamanho = 96
    bossEscala = bossTamanho / bossImg:getWidth()

    -- 4b. BOSS 2 (CTHULHU) - Surge 30s após derrotar o Boss 1 (requer 60 tiros)
    cthulhuImg = love.graphics.newImage("image/cthulhu.png")
    cthulhuTamanho = 110
    cthulhuEscala = cthulhuTamanho / cthulhuImg:getWidth()

    -- 5. TIRO DO BOSS (ENEMY POWER)
    enemyPowerImg = love.graphics.newImage("image/enemyPower.png")
    enemyPowerTamanho = 32
    enemyPowerEscala = enemyPowerTamanho / enemyPowerImg:getWidth()

    -- 6. MÚSICAS DO JOGO
    musicaFundo = love.audio.newSource("songs/theme-spiderman-8-bit.mp3", "stream")
    musicaFundo:setLooping(true)
    musicaFundo:setVolume(0.5)
    musicaFundo:play()

    -- Música da Batalha contra o Boss (battle.mp3)
    musicaBatalha = love.audio.newSource("songs/battle.mp3", "stream")
    musicaBatalha:setLooping(true)
    musicaBatalha:setVolume(0.5)

    -- 7. CENÁRIO DE FUNDO
    fundoImg = love.graphics.newImage("image/cenary.jpg")
    fundoEscalaX = love.graphics.getWidth() / fundoImg:getWidth()
    fundoEscalaY = love.graphics.getHeight() / fundoImg:getHeight()

    -- 8. ITEM DE CORAÇÃO (VIDA EXTRA)
    coracaoImg = love.graphics.newImage("image/heart.png")
    coracaoTamanho = 36
    coracaoEscala = coracaoTamanho / coracaoImg:getWidth()

    -- 9. ITENS DE POWER-UP (TIRO RÁPIDO, ESCUDO E FUTUROS)
    powerupImg = love.graphics.newImage("image/powerup.png")
    powerupTamanho = 36
    powerupEscala = powerupTamanho / powerupImg:getWidth()

    powerupShieldImg = love.graphics.newImage("image/powerup_shield.png")
    powerupShieldTamanho = 36
    powerupShieldEscala = powerupShieldTamanho / powerupShieldImg:getWidth()

    -- Tabela de Power-ups para rotação randômica a cada 35s
    -- (Basta adicionar novas entradas aqui quando criar novos power-ups!)
    tiposPowerup = {
        {
            id = "tiro_rapido",
            nome = "Tiro 2x",
            imagem = powerupImg,
            escala = powerupEscala,
            tamanho = powerupTamanho,
            cor = {0.9, 0.45, 1.0},
            aoColetar = function()
                timerTiroRapidoAtivo = 10.0
            end
        },
        {
            id = "escudo",
            nome = "Escudo",
            imagem = powerupShieldImg,
            escala = powerupShieldEscala,
            tamanho = powerupShieldTamanho,
            cor = {0.3, 0.85, 1.0},
            aoColetar = function()
                timerEscudoAtivo = 10.0
            end
        }
    }
end

function love.update(dt)
    if estado == "menu" then
        -- Movimenta o texto do título
        x = x + velocidadeTexto * dt
        if x > love.graphics.getWidth() then
            x = -150
        end

    elseif estado == "jogando" then
        -- Incrementa o tempo decorrido da partida
        tempoPartida = tempoPartida + dt

        -- 1. Movimentação do Jogador (WASD e Setas)
        if love.keyboard.isDown("d", "right") then
            jogador.x = jogador.x + jogador.velocidade * dt
        end
        if love.keyboard.isDown("a", "left") then
            jogador.x = jogador.x - jogador.velocidade * dt
        end
        if love.keyboard.isDown("w", "up") then
            jogador.y = jogador.y - jogador.velocidade * dt
        end
        if love.keyboard.isDown("s", "down") then
            jogador.y = jogador.y + jogador.velocidade * dt
        end

        -- Limites de tela para o jogador não sair
        local metade = jogador.tamanho / 2
        jogador.x = math.max(metade, math.min(love.graphics.getWidth() - metade, jogador.x))
        jogador.y = math.max(metade, math.min(love.graphics.getHeight() - metade, jogador.y))

        -- Reduz tempo de invulnerabilidade após levar dano
        if jogador.tempoInvulneravel > 0 then
            jogador.tempoInvulneravel = jogador.tempoInvulneravel - dt
        end

        -- Reduz tempo dos power-ups ativos
        if timerTiroRapidoAtivo > 0 then
            timerTiroRapidoAtivo = timerTiroRapidoAtivo - dt
        end
        if timerEscudoAtivo > 0 then
            timerEscudoAtivo = timerEscudoAtivo - dt
        end

        -- 2. Sistema de Disparo Contínuo do Jogador (segurando o botão esquerdo do mouse)
        if timerTiro > 0 then
            timerTiro = timerTiro - dt
        end

        local intervaloAtual = (timerTiroRapidoAtivo > 0) and (intervaloTiro / 2) or intervaloTiro
        local velTiroAtual = (timerTiroRapidoAtivo > 0) and 750 or 500

        if love.mouse.isDown(1) and timerTiro <= 0 then
            timerTiro = intervaloAtual

            local mx, my = love.mouse.getPosition()
            local angulo = math.atan2(my - jogador.y, mx - jogador.x)
            table.insert(tiros, {
                x = jogador.x,
                y = jogador.y,
                dx = math.cos(angulo),
                dy = math.sin(angulo),
                angulo = angulo,
                velocidade = velTiroAtual
            })
        end

        -- 3. Atualiza os Tiros do Jogador
        for i = #tiros, 1, -1 do
            local tiro = tiros[i]
            tiro.x = tiro.x + tiro.dx * tiro.velocidade * dt
            tiro.y = tiro.y + tiro.dy * tiro.velocidade * dt

            if tiro.x < -50 or tiro.x > love.graphics.getWidth() + 50 or
               tiro.y < -50 or tiro.y > love.graphics.getHeight() + 50 then
                table.remove(tiros, i)
            end
        end

        -- 4 e 5. Inimigos Normais (Ficam pausados enquanto o Boss estiver ativo ou entrando)
        if not boss and not bossEntrando then
            -- Spawn periódico de Inimigos Normais ao redor da tela
            timerSpawn = timerSpawn - dt
            if timerSpawn <= 0 then
                local intervaloSpawn = math.max(0.6, 1.2 - (tempoPartida * 0.008))
                timerSpawn = intervaloSpawn

                local borda = love.math.random(1, 4)
                local ex, ey
                if borda == 1 then -- Topo
                    ex = love.math.random(0, love.graphics.getWidth())
                    ey = -40
                elseif borda == 2 then -- Fundo
                    ex = love.math.random(0, love.graphics.getWidth())
                    ey = love.graphics.getHeight() + 40
                elseif borda == 3 then -- Esquerda
                    ex = -40
                    ey = love.math.random(0, love.graphics.getHeight())
                else -- Direita
                    ex = love.graphics.getWidth() + 40
                    ey = love.math.random(0, love.graphics.getHeight())
                end

                local bonusVelocidade = math.min(110, tempoPartida * 2.0)
                local velMin = 80 + bonusVelocidade
                local velMax = 130 + bonusVelocidade

                -- Define o tipo de inimigo:
                -- Se o primeiro boss já foi derrotado, surge também o Enemy 2 (40% de chance)
                local tipoInimigo = 1
                local vidaInimigo = 1
                local tamInimigo = inimigoTamanho
                if boss1Derrotado and love.math.random() < 0.45 then
                    tipoInimigo = 2
                    vidaInimigo = 2
                    tamInimigo = inimigo2Tamanho
                end

                table.insert(inimigos, {
                    x = ex,
                    y = ey,
                    tipo = tipoInimigo,
                    vida = vidaInimigo,
                    velocidade = love.math.random(velMin, velMax),
                    tamanho = tamInimigo
                })
            end

            -- Movimenta os Inimigos Normais perseguindo o Jogador
            for i = #inimigos, 1, -1 do
                local inimigo = inimigos[i]
                local angulo = math.atan2(jogador.y - inimigo.y, jogador.x - inimigo.x)
                inimigo.x = inimigo.x + math.cos(angulo) * inimigo.velocidade * dt
                inimigo.y = inimigo.y + math.sin(angulo) * inimigo.velocidade * dt

                -- Checa colisão com o Jogador
                if colisaoCirculo(inimigo.x, inimigo.y, inimigo.tamanho / 2.2, jogador.x, jogador.y, jogador.tamanho / 2.2) then
                    local pontosGanhos = (inimigo.tipo == 2) and 20 or 10
                    if timerEscudoAtivo > 0 then
                        -- Escudo ativo: destrói o inimigo sem dar dano ao jogador
                        table.remove(inimigos, i)
                        pontos = pontos + pontosGanhos
                    elseif jogador.tempoInvulneravel <= 0 then
                        jogador.vidas = jogador.vidas - 1
                        jogador.tempoInvulneravel = 1.0
                        table.remove(inimigos, i)

                        if jogador.vidas <= 0 then
                            estado = "gameover"
                        end
                    end
                end
            end
        end

        -- 6. SPAWN E COMPORTAMENTO DO BOSS 1 (surge aos 30 segundos com 5s de introdução)
        if tempoPartida >= 30 and not bossJaApareceu then
            bossJaApareceu = true
            bossEntrando = true
            timerIntroBoss = 5.0 -- 5 segundos de pausa para o Boss entrar em cena

            -- Pausa música normal e troca para a música de batalha
            if musicaFundo and musicaFundo:isPlaying() then
                musicaFundo:pause()
            end
            if musicaBatalha then
                musicaBatalha:play()
            end

            boss = {
                tipo = 1,
                nome = "Chefão",
                x = love.graphics.getWidth() / 2,
                y = -120, -- Começa fora da tela no topo
                alvoY = 120, -- Posição de parada durante a introdução
                velocidade = 170,
                tamanho = bossTamanho,
                vida = 30,
                vidaMaxima = 30,
                timerTiro = 1.0,
                intervaloTiro = 1.3
            }
        end

        -- 6b. SPAWN DO SEGUNDO BOSS (CTHULHU - surge 30s após derrotar o primeiro boss)
        if boss1Derrotado and not boss2JaApareceu and not boss and not bossEntrando then
            timerSpawnBoss2 = timerSpawnBoss2 - dt
            if timerSpawnBoss2 <= 0 then
                boss2JaApareceu = true
                bossEntrando = true
                timerIntroBoss = 5.0 -- 5 segundos de introdução para Cthulhu

                -- Pausa música normal e toca música de batalha
                if musicaFundo and musicaFundo:isPlaying() then
                    musicaFundo:pause()
                end
                if musicaBatalha then
                    musicaBatalha:play()
                end

                boss = {
                    tipo = 2,
                    nome = "CTHULHU",
                    x = love.graphics.getWidth() / 2,
                    y = -130,
                    alvoY = 120,
                    velocidade = 145,
                    tamanho = cthulhuTamanho,
                    vida = 60, -- Dobro de vida do primeiro boss (30 * 2 = 60)
                    vidaMaxima = 60,
                    timerTiro = 1.0, -- Dispara logo após entrar
                    intervaloTiro = 5.0,
                    timerVulneravel = 0
                }
            end
        end

        if boss then
            if bossEntrando then
                -- Durante a pausa de 5 segundos da entrada:
                timerIntroBoss = timerIntroBoss - dt
                -- Desce suavemente até a posição alvo
                boss.y = boss.y + (boss.alvoY - boss.y) * 2.0 * dt

                if timerIntroBoss <= 0 then
                    bossEntrando = false -- Fim da pausa, inicia a batalha!
                end
            else
                -- Batalha ativa do Boss:
                local anguloBoss = math.atan2(jogador.y - boss.y, jogador.x - boss.x)
                boss.x = boss.x + math.cos(anguloBoss) * boss.velocidade * dt
                boss.y = boss.y + math.sin(anguloBoss) * boss.velocidade * dt

                if boss.tipo == 1 then
                    -- Boss 1 atira contra o Jogador (enemyPower)
                    boss.timerTiro = boss.timerTiro - dt
                    if boss.timerTiro <= 0 then
                        boss.timerTiro = boss.intervaloTiro
                        local anguloTiroBoss = math.atan2(jogador.y - boss.y, jogador.x - boss.x)
                        table.insert(tirosInimigos, {
                            x = boss.x,
                            y = boss.y,
                            dx = math.cos(anguloTiroBoss),
                            dy = math.sin(anguloTiroBoss),
                            angulo = anguloTiroBoss,
                            velocidade = 230,
                            tamanho = enemyPowerTamanho
                        })
                    end
                elseif boss.tipo == 2 then
                    -- Boss 2 (Cthulhu): atira 3 poderes de uma só vez e fica vulnerável por 3s
                    boss.timerTiro = boss.timerTiro - dt
                    if boss.timerTiro <= 0 then
                        boss.timerTiro = 5.0 -- Novo ciclo a cada 5 segundos
                        boss.timerVulneravel = 3.0 -- Fica vulnerável por 3 segundos enquanto atira!

                        -- 3 tiros: 1 para cima, 2 para diagonais inferiores em cada lado
                        local projeteisCthulhu = {
                            {dx = 0, dy = -1, angulo = -math.pi / 2}, -- Para cima
                            {dx = -0.7071, dy = 0.7071, angulo = math.pi * 0.75}, -- Diagonal inferior esquerda
                            {dx = 0.7071, dy = 0.7071, angulo = math.pi * 0.25} -- Diagonal inferior direita
                        }
                        for _, p in ipairs(projeteisCthulhu) do
                            table.insert(tirosInimigos, {
                                x = boss.x,
                                y = boss.y,
                                dx = p.dx,
                                dy = p.dy,
                                angulo = p.angulo,
                                velocidade = 240,
                                tamanho = enemyPowerTamanho
                            })
                        end
                    end

                    -- Decrementa o tempo de vulnerabilidade do Cthulhu
                    if boss.timerVulneravel and boss.timerVulneravel > 0 then
                        boss.timerVulneravel = boss.timerVulneravel - dt
                    end
                end

                if colisaoCirculo(boss.x, boss.y, boss.tamanho / 2.3, jogador.x, jogador.y, jogador.tamanho / 2.3) then
                    if timerEscudoAtivo > 0 then
                        -- Escudo ativo: imune a dano de contato com o Chefão
                    elseif jogador.tempoInvulneravel <= 0 then
                        jogador.vidas = jogador.vidas - 1
                        jogador.tempoInvulneravel = 1.2
                        if jogador.vidas <= 0 then
                            estado = "gameover"
                        end
                    end
                end
            end
        end

        -- 7. Atualiza os Tiros do Boss e checa colisão com o Jogador
        for i = #tirosInimigos, 1, -1 do
            local tiroE = tirosInimigos[i]
            tiroE.x = tiroE.x + tiroE.dx * tiroE.velocidade * dt
            tiroE.y = tiroE.y + tiroE.dy * tiroE.velocidade * dt

            -- Checa se o tiro do boss acertou o jogador
            if colisaoCirculo(tiroE.x, tiroE.y, tiroE.tamanho / 2.2, jogador.x, jogador.y, jogador.tamanho / 2.2) then
                if timerEscudoAtivo > 0 then
                    -- Escudo ativo: projétil inimigo é absorvido sem causar dano
                    table.remove(tirosInimigos, i)
                elseif jogador.tempoInvulneravel <= 0 then
                    jogador.vidas = jogador.vidas - 1
                    jogador.tempoInvulneravel = 1.0
                    table.remove(tirosInimigos, i)
                    if jogador.vidas <= 0 then
                        estado = "gameover"
                    end
                end
            elseif tiroE.x < -50 or tiroE.x > love.graphics.getWidth() + 50 or
                   tiroE.y < -50 or tiroE.y > love.graphics.getHeight() + 50 then
                table.remove(tirosInimigos, i)
            end
        end

        -- 8. Checa colisão dos Tiros do Jogador com o Boss e Inimigos
        for t = #tiros, 1, -1 do
            local tiro = tiros[t]
            local acertouAlgo = false

            -- Primeiro checa se acertou o Boss (apenas após a introdução de 5s)
            if boss and not bossEntrando and colisaoCirculo(tiro.x, tiro.y, poderTamanho / 2, boss.x, boss.y, boss.tamanho / 2.2) then
                table.remove(tiros, t)
                acertouAlgo = true

                -- Checa se o Boss pode ser atingido:
                -- Cthulhu (tipo 2) só pode ser atingido no intervalo de 3s enquanto atira!
                local podeDano = true
                if boss.tipo == 2 then
                    podeDano = (boss.timerVulneravel and boss.timerVulneravel > 0)
                end

                if podeDano then
                    boss.vida = boss.vida - 1

                    if boss.vida <= 0 then
                        local recompensa = (boss.tipo == 2) and 600 or 300
                        pontos = pontos + recompensa

                        if boss.tipo == 1 then
                            boss1Derrotado = true
                            timerSpawnBoss2 = 30 -- Segundo boss surge 30s após derrotar o primeiro!
                        elseif boss.tipo == 2 then
                            boss2Derrotado = true
                        end

                        boss = nil

                        -- Quando o Boss é derrotado: para a música de batalha e retoma a música normal
                        if musicaBatalha and musicaBatalha:isPlaying() then
                            musicaBatalha:stop()
                        end
                        if musicaFundo then
                            musicaFundo:play()
                        end
                    end
                end
            end

            -- Se não acertou o Boss, checa os inimigos (normal e enemy2)
            if not acertouAlgo then
                for ini = #inimigos, 1, -1 do
                    local inimigo = inimigos[ini]
                    if colisaoCirculo(tiro.x, tiro.y, poderTamanho / 2, inimigo.x, inimigo.y, inimigo.tamanho / 2) then
                        table.remove(tiros, t)
                        inimigo.vida = inimigo.vida - 1
                        -- Enemy 1 precisa de 1 tiro, Enemy 2 precisa de 2 tiros para morrer
                        if inimigo.vida <= 0 then
                            local pontosGanhos = (inimigo.tipo == 2) and 20 or 10
                            pontos = pontos + pontosGanhos
                            table.remove(inimigos, ini)
                        end
                        break
                    end
                end
            end
        end

        -- 9. SPAWN E COLETA DO CORAÇÃO DE CURA (surge a cada 30s, dura 5s)
        timerSpawnCoracao = timerSpawnCoracao - dt
        if timerSpawnCoracao <= 0 then
            timerSpawnCoracao = 30 -- reinicia contador para o próximo em 30 segundos
            coracao = {
                x = love.math.random(80, love.graphics.getWidth() - 80),
                y = love.math.random(80, love.graphics.getHeight() - 80),
                tempoRestante = 5.0,
                tamanho = coracaoTamanho
            }
        end

        if coracao then
            coracao.tempoRestante = coracao.tempoRestante - dt
            -- Desaparece se não for coletado dentro de 5 segundos
            if coracao.tempoRestante <= 0 then
                coracao = nil
            -- Coleta ao encostar no jogador
            elseif colisaoCirculo(jogador.x, jogador.y, jogador.tamanho / 2.2, coracao.x, coracao.y, coracao.tamanho / 2) then
                if jogador.vidas < 3 then
                    jogador.vidas = jogador.vidas + 1 -- Recupera 1 vida!
                else
                    pontos = pontos + 50 -- Bônus de pontuação se já estiver cheio
                end
                coracao = nil
            end
        end

        -- 10. SPAWN E COLETA DE POWER-UPS RANDÔMICOS (surge a cada 35s, dura 5s)
        timerSpawnPowerup = timerSpawnPowerup - dt
        if timerSpawnPowerup <= 0 then
            timerSpawnPowerup = 35 -- reinicia contador para o próximo em 35 segundos
            if #tiposPowerup > 0 then
                local tipoSorteado = tiposPowerup[love.math.random(1, #tiposPowerup)]
                powerup = {
                    tipo = tipoSorteado,
                    x = love.math.random(80, love.graphics.getWidth() - 80),
                    y = love.math.random(80, love.graphics.getHeight() - 80),
                    tempoRestante = 5.0,
                    tamanho = tipoSorteado.tamanho
                }
            end
        end

        if powerup then
            powerup.tempoRestante = powerup.tempoRestante - dt
            -- Desaparece se não for coletado dentro de 5 segundos
            if powerup.tempoRestante <= 0 then
                powerup = nil
            -- Coleta ao encostar no jogador (executa o efeito do powerup sorteado)
            elseif colisaoCirculo(jogador.x, jogador.y, jogador.tamanho / 2.2, powerup.x, powerup.y, powerup.tamanho / 2) then
                powerup.tipo.aoColetar()
                powerup = nil
            end
        end
    end
end

function love.draw()
    -- 0. Desenha o Cenário de fundo ajustado à tela
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(fundoImg, 0, 0, 0, fundoEscalaX, fundoEscalaY)

    if estado == "menu" then
        -- Escurece levemente o fundo no menu para destacar o botão e o herói
        love.graphics.setColor(0, 0, 0, 0.45)
        love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
        -- Título animado
        love.graphics.setColor(1, 1, 1)
        love.graphics.print("Jogo do Miranha", x, 100)

        -- Destaque do herói no menu
        local centroX = jogador.imagem:getWidth() / 2
        local centroY = jogador.imagem:getHeight() / 2
        love.graphics.draw(jogador.imagem, love.graphics.getWidth() / 2, (love.graphics.getHeight() / 2) - 20, 0, jogador.escala * 1.2, jogador.escala * 1.2, centroX, centroY)

        -- Botão Iniciar Jogo
        local mx, my = love.mouse.getPosition()
        local sobreBotao = pontoNoRetangulo(mx, my, botao.x, botao.y, botao.largura, botao.altura)
        if sobreBotao then
            love.graphics.setColor(0.2, 0.6, 1.0)
        else
            love.graphics.setColor(0.1, 0.4, 0.8)
        end
        love.graphics.rectangle("fill", botao.x, botao.y, botao.largura, botao.altura, 8, 8)
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf(botao.texto, botao.x, botao.y + 17, botao.largura, "center")

    elseif estado == "jogando" then
        -- 1. Desenha os Poderes do Jogador
        love.graphics.setColor(1, 1, 1)
        local poderCentroX = poderImg:getWidth() / 2
        local poderCentroY = poderImg:getHeight() / 2
        for _, tiro in ipairs(tiros) do
            love.graphics.draw(poderImg, tiro.x, tiro.y, tiro.angulo, poderEscala, poderEscala, poderCentroX, poderCentroY)
        end

        -- 2. Desenha os Tiros do Boss (enemyPower)
        local epCentroX = enemyPowerImg:getWidth() / 2
        local epCentroY = enemyPowerImg:getHeight() / 2
        for _, tiroE in ipairs(tirosInimigos) do
            love.graphics.draw(enemyPowerImg, tiroE.x, tiroE.y, tiroE.angulo, enemyPowerEscala, enemyPowerEscala, epCentroX, epCentroY)
        end

        -- 3. Desenha os Inimigos Normais
        local iniCentroX = inimigoImg:getWidth() / 2
        local iniCentroY = inimigoImg:getHeight() / 2
        for _, inimigo in ipairs(inimigos) do
            love.graphics.draw(inimigoImg, inimigo.x, inimigo.y, 0, inimigoEscala, inimigoEscala, iniCentroX, iniCentroY)
        end

        -- 4. Desenha o Coração de Recuperar Vida (se ativo na tela)
        if coracao then
            local coracaoCentroX = coracaoImg:getWidth() / 2
            local coracaoCentroY = coracaoImg:getHeight() / 2

            -- Pisca nos últimos 1.5 segundos para avisar que vai sumir
            if coracao.tempoRestante <= 1.5 and math.floor(coracao.tempoRestante * 8) % 2 == 0 then
                love.graphics.setColor(1, 1, 1, 0.25)
            else
                love.graphics.setColor(1, 1, 1, 1)
            end

            -- Efeito de pulsar suave
            local pulso = 1 + math.sin(love.timer.getTime() * 8) * 0.12
            local escalaFinal = coracaoEscala * pulso
            love.graphics.draw(coracaoImg, coracao.x, coracao.y, 0, escalaFinal, escalaFinal, coracaoCentroX, coracaoCentroY)
        end

        -- 4b. Desenha o Power-up no cenário (se ativo na tela)
        if powerup then
            local img = powerup.tipo.imagem
            local escala = powerup.tipo.escala
            local centroX = img:getWidth() / 2
            local centroY = img:getHeight() / 2

            -- Pisca nos últimos 1.5 segundos para avisar que vai sumir
            if powerup.tempoRestante <= 1.5 and math.floor(powerup.tempoRestante * 8) % 2 == 0 then
                love.graphics.setColor(1, 1, 1, 0.25)
            else
                love.graphics.setColor(1, 1, 1, 1)
            end

            -- Efeito de pulsar suave
            local pulso = 1 + math.sin(love.timer.getTime() * 8) * 0.12
            local escalaFinal = escala * pulso
            love.graphics.draw(img, powerup.x, powerup.y, 0, escalaFinal, escalaFinal, centroX, centroY)
        end

        -- 5. Desenha o BOSS e sua barra de vida
        if boss then
            local bossCentroX = bossImg:getWidth() / 2
            local bossCentroY = bossImg:getHeight() / 2
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(bossImg, boss.x, boss.y, 0, bossEscala, bossEscala, bossCentroX, bossCentroY)

            -- Barra de Vida sobre a cabeça do Boss
            local barraLargura = 90
            local barraAltura = 8
            local barraX = boss.x - barraLargura / 2
            local barraY = boss.y - (boss.tamanho / 2) - 16

            -- Fundo da barra
            love.graphics.setColor(0.1, 0.1, 0.1, 0.8)
            love.graphics.rectangle("fill", barraX, barraY, barraLargura, barraAltura, 3, 3)

            -- Barra vermelha proporcional à vida
            local percVida = math.max(0, boss.vida / boss.vidaMaxima)
            love.graphics.setColor(0.9, 0.2, 0.2, 1)
            love.graphics.rectangle("fill", barraX, barraY, barraLargura * percVida, barraAltura, 3, 3)

            -- Contorno branco
            love.graphics.setColor(1, 1, 1, 0.8)
            love.graphics.rectangle("line", barraX, barraY, barraLargura, barraAltura, 3, 3)
        end

        -- 5. Desenha o Super-herói (pisca se estiver invulnerável)
        local centroX = jogador.imagem:getWidth() / 2
        local centroY = jogador.imagem:getHeight() / 2
        if jogador.tempoInvulneravel > 0 and math.floor(jogador.tempoInvulneravel * 10) % 2 == 0 then
            love.graphics.setColor(1, 1, 1, 0.3)
        else
            love.graphics.setColor(1, 1, 1, 1)
        end
        love.graphics.draw(jogador.imagem, jogador.x, jogador.y, 0, jogador.escala, jogador.escala, centroX, centroY)

        -- Aura de energia ao redor do herói quando o tiro rápido está ativo
        if timerTiroRapidoAtivo > 0 then
            local alphaAura = 0.4 + math.sin(love.timer.getTime() * 12) * 0.25
            love.graphics.setColor(0.85, 0.4, 1.0, alphaAura)
            love.graphics.setLineWidth(2)
            love.graphics.circle("line", jogador.x, jogador.y, (jogador.tamanho / 2) + 6)
            love.graphics.setLineWidth(1)
        end

        -- Campo de força do escudo protetor quando ativo
        if timerEscudoAtivo > 0 then
            local pulsoEscudo = 1 + math.sin(love.timer.getTime() * 6) * 0.05
            local raioEscudo = (jogador.tamanho / 1.7) * pulsoEscudo

            -- Bolha translúcida azulada
            love.graphics.setColor(0.2, 0.7, 1.0, 0.22)
            love.graphics.circle("fill", jogador.x, jogador.y, raioEscudo)

            -- Anel brilhante externo do escudo
            local alphaBorda = 0.6 + math.sin(love.timer.getTime() * 8) * 0.3
            love.graphics.setColor(0.4, 0.9, 1.0, alphaBorda)
            love.graphics.setLineWidth(3)
            love.graphics.circle("line", jogador.x, jogador.y, raioEscudo)
            love.graphics.setLineWidth(1)
        end

        -- 6. Placar, Tempo e HUD
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print("Pontos: " .. pontos, 20, 20)

        -- Indicadores dos Power-ups ativos no HUD
        local yBuff = 44
        if timerTiroRapidoAtivo > 0 then
            love.graphics.setColor(1, 1, 1, 1)
            local miniEscala = 18 / powerupImg:getWidth()
            love.graphics.draw(powerupImg, 20, yBuff, 0, miniEscala, miniEscala)
            love.graphics.setColor(0.9, 0.45, 1.0, 1)
            love.graphics.print(string.format("Tiro 2x: %.1fs", timerTiroRapidoAtivo), 44, yBuff + 1)
            yBuff = yBuff + 22
        end

        if timerEscudoAtivo > 0 then
            love.graphics.setColor(1, 1, 1, 1)
            local miniEscala = 18 / powerupShieldImg:getWidth()
            love.graphics.draw(powerupShieldImg, 20, yBuff, 0, miniEscala, miniEscala)
            love.graphics.setColor(0.3, 0.85, 1.0, 1)
            love.graphics.print(string.format("Escudo: %.1fs", timerEscudoAtivo), 44, yBuff + 1)
            yBuff = yBuff + 22
        end

        -- Exibe o tempo de sobrevivência no centro do topo
        local minutos = math.floor(tempoPartida / 60)
        local segundos = math.floor(tempoPartida % 60)
        love.graphics.printf(string.format("Tempo: %02d:%02d", minutos, segundos), 0, 20, love.graphics.getWidth(), "center")

        -- Alerta visual quando o Boss está em batalha ou entrando
        if bossEntrando then
            -- Banner cinematográfico durante os 5 segundos de entrada
            love.graphics.setColor(0, 0, 0, 0.6)
            love.graphics.rectangle("fill", 0, (love.graphics.getHeight() / 2) - 45, love.graphics.getWidth(), 80)

            love.graphics.setColor(1, 0.2, 0.2, 1)
            love.graphics.printf("! ATENÇÃO: O CHEFÃO ESTÁ CHEGANDO !", 0, (love.graphics.getHeight() / 2) - 30, love.graphics.getWidth(), "center")

            love.graphics.setColor(1, 1, 0, 1)
            local contagem = math.ceil(timerIntroBoss)
            love.graphics.printf("BATALHA EM: " .. contagem .. "s", 0, (love.graphics.getHeight() / 2) + 5, love.graphics.getWidth(), "center")

        elseif boss then
            love.graphics.setColor(1, 0.3, 0.3, 1)
            love.graphics.printf("! CHEFÃO EM BATALHA !", 0, 42, love.graphics.getWidth(), "center")
        end

        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print("Vidas: " .. jogador.vidas, love.graphics.getWidth() - 100, 20)
        love.graphics.printf("WASD/Setas: mover | Segure Clique Esquerdo: atirar contínuo | ESC: menu", 0, love.graphics.getHeight() - 30, love.graphics.getWidth(), "center")

    elseif estado == "gameover" then
        -- Fundo escurecido para a tela de game over
        love.graphics.setColor(0, 0, 0, 0.75)
        love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())

        love.graphics.setColor(1, 0.3, 0.3)
        love.graphics.printf("FIM DE JOGO!", 0, (love.graphics.getHeight() / 2) - 70, love.graphics.getWidth(), "center")

        love.graphics.setColor(1, 1, 1)
        love.graphics.printf("Pontuação Final: " .. pontos, 0, (love.graphics.getHeight() / 2) - 30, love.graphics.getWidth(), "center")
        
        local minFinal = math.floor(tempoPartida / 60)
        local segFinal = math.floor(tempoPartida % 60)
        love.graphics.printf(string.format("Tempo Sobrevivido: %02d:%02d", minFinal, segFinal), 0, (love.graphics.getHeight() / 2) - 5, love.graphics.getWidth(), "center")

        love.graphics.printf("Pressione R para Jogar Novamente ou ESC para o Menu", 0, (love.graphics.getHeight() / 2) + 30, love.graphics.getWidth(), "center")
    end
end

function love.mousepressed(mx, my, button)
    if button == 1 then
        if estado == "menu" then
            if pontoNoRetangulo(mx, my, botao.x, botao.y, botao.largura, botao.altura) then
                reiniciarJogo()
            end
        end
    end
end

function love.keypressed(key)
    if key == "escape" then
        estado = "menu"
        if musicaBatalha and musicaBatalha:isPlaying() then
            musicaBatalha:stop()
        end
        if musicaFundo then
            musicaFundo:play()
        end
    elseif key == "r" and estado == "gameover" then
        reiniciarJogo()
    end
end