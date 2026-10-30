local UI = {}

local function pontoDentroDoRetangulo(px, py, x, y, largura, altura)
    return px >= x
        and px <= x + largura
        and py >= y
        and py <= y + altura
end

local function formatarTempo(tempo)
    local minutos = math.floor(tempo / 60)
    local segundos = math.floor(tempo % 60)

    return string.format("%02d:%02d", minutos, segundos)
end

local function desenharBotaoMenu(botao, texto, selecionado)
    local mouseX, mouseY = love.mouse.getPosition()
    local sobMouse = pontoDentroDoRetangulo(
        mouseX,
        mouseY,
        botao.x,
        botao.y,
        botao.largura,
        botao.altura
    )

    if selecionado then
        love.graphics.setColor(0.15, 0.65, 0.35)
    elseif sobMouse then
        love.graphics.setColor(0.2, 0.6, 1)
    else
        love.graphics.setColor(0.1, 0.4, 0.8)
    end

    love.graphics.rectangle(
        "fill",
        botao.x,
        botao.y,
        botao.largura,
        botao.altura,
        8,
        8
    )

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf(
        texto or botao.texto,
        botao.x,
        botao.y + (botao.altura - love.graphics.getFont():getHeight()) / 2,
        botao.largura,
        "center"
    )
end

function UI.new(larguraTela, alturaTela)
    local alturaBotaoMenu = 50
    local larguraBotaoMenu = 200
    local larguraBotaoPausa = 240
    local alturaBotaoPausa = 50
    local titulo = "JOGO DO MIRANHA"
    local fonteTitulo = love.graphics.newFont(
        "fonts/PressStart2P-Regular.ttf",
        24
    )
    local resolucoes = {
        { largura = 800, altura = 600 },
        { largura = 1024, altura = 768 },
        { largura = 1280, altura = 720 }
    }
    local larguraBotaoResolucao = 150
    local espacamentoResolucao = 12
    local larguraTotalResolucao =
        #resolucoes * larguraBotaoResolucao
        + (#resolucoes - 1) * espacamentoResolucao
    local xResolucao = (larguraTela - larguraTotalResolucao) / 2
    local botoesResolucao = {}

    for indice, resolucao in ipairs(resolucoes) do
        botoesResolucao[indice] = {
            x = xResolucao + (indice - 1) *
                (larguraBotaoResolucao + espacamentoResolucao),
            y = alturaTela * 0.62,
            largura = larguraBotaoResolucao,
            altura = 46,
            texto = resolucao.largura .. " x " .. resolucao.altura,
            resolucao = resolucao
        }
    end

    local ui = {
        titulo = titulo,
        tituloX = 0,
        tituloDirecao = 1,
        velocidadeTitulo = 120,
        tempoJogadorMenu = 0,
        fontePadrao = love.graphics.getFont(),
        fonteTitulo = fonteTitulo,
        botao = {
            x = (larguraTela - larguraBotaoMenu) / 2,
            y = (alturaTela / 2) + 30,
            largura = larguraBotaoMenu,
            altura = alturaBotaoMenu
        },
        botaoInstrucoes = {
            x = (larguraTela - larguraBotaoMenu) / 2,
            y = (alturaTela / 2) + 86,
            largura = larguraBotaoMenu,
            altura = alturaBotaoMenu
        },
        botaoConfiguracoesMenu = {
            x = (larguraTela - larguraBotaoMenu) / 2,
            y = (alturaTela / 2) + 142,
            largura = larguraBotaoMenu,
            altura = alturaBotaoMenu,
            texto = "Configurações"
        },
        botaoSair = {
            x = (larguraTela - larguraBotaoMenu) / 2,
            y = (alturaTela / 2) + 198,
            largura = larguraBotaoMenu,
            altura = alturaBotaoMenu,
            texto = "Sair do jogo"
        },
        botaoVoltarInstrucoes = {
            texto = "Voltar ao menu",
            x = (larguraTela - larguraBotaoMenu) / 2,
            y = alturaTela - 90,
            largura = larguraBotaoMenu,
            altura = alturaBotaoMenu
        },
        configuracaoVolume = {
            x = larguraTela * 0.25,
            y = alturaTela * 0.38,
            largura = larguraTela * 0.5,
            altura = 14
        },
        botoesResolucao = botoesResolucao,
        botoesPausa = {
            voltar = {
                texto = "Voltar ao jogo",
                acao = "voltar",
                x = (larguraTela - larguraBotaoPausa) / 2,
                y = (alturaTela / 2) - 25,
                largura = larguraBotaoPausa,
                altura = alturaBotaoPausa
            },
            menu = {
                texto = "Menu principal",
                acao = "menu",
                x = (larguraTela - larguraBotaoPausa) / 2,
                y = (alturaTela / 2) + 35,
                largura = larguraBotaoPausa,
                altura = alturaBotaoPausa
            },
            configuracoes = {
                texto = "Configurações",
                acao = "configuracoes",
                x = (larguraTela - larguraBotaoPausa) / 2,
                y = (alturaTela / 2) + 95,
                largura = larguraBotaoPausa,
                altura = alturaBotaoPausa
            },
            fechar = {
                texto = "Fechar jogo",
                acao = "fechar",
                x = (larguraTela - larguraBotaoPausa) / 2,
                y = (alturaTela / 2) + 155,
                largura = larguraBotaoPausa,
                altura = alturaBotaoPausa
            }
        },

        botaoVoltarConfiguracoes = {
            texto = "Voltar",
            x = (larguraTela - larguraBotaoPausa) / 2,
            y = alturaTela - 90,
            largura = larguraBotaoPausa,
            altura = alturaBotaoPausa
        }
    }

    return ui
end

function UI.resize(ui, larguraTela, alturaTela)
    local larguraBotaoMenu = ui.botao.largura
    local larguraBotaoPausa = ui.botoesPausa.voltar.largura

    ui.botao.x = (larguraTela - larguraBotaoMenu) / 2
    ui.botao.y = (alturaTela / 2) + 30
    ui.botaoInstrucoes.x = (larguraTela - ui.botaoInstrucoes.largura) / 2
    ui.botaoInstrucoes.y = ui.botao.y + 56
    ui.botaoConfiguracoesMenu.x =
        (larguraTela - ui.botaoConfiguracoesMenu.largura) / 2
    ui.botaoConfiguracoesMenu.y = ui.botao.y + 112
    ui.botaoSair.x = (larguraTela - ui.botaoSair.largura) / 2
    ui.botaoSair.y = ui.botao.y + 168
    ui.botaoVoltarInstrucoes.x =
        (larguraTela - ui.botaoVoltarInstrucoes.largura) / 2
    ui.botaoVoltarInstrucoes.y = alturaTela - 90
    ui.configuracaoVolume.x = larguraTela * 0.25
    ui.configuracaoVolume.y = alturaTela * 0.38
    ui.configuracaoVolume.largura = larguraTela * 0.5
    ui.botaoVoltarConfiguracoes.x =
        (larguraTela - larguraBotaoPausa) / 2
    ui.botaoVoltarConfiguracoes.y = alturaTela - 90
    ui.botoesPausa.voltar.x = ui.botaoVoltarConfiguracoes.x
    ui.botoesPausa.menu.x = ui.botaoVoltarConfiguracoes.x
    ui.botoesPausa.configuracoes.x = ui.botaoVoltarConfiguracoes.x
    ui.botoesPausa.fechar.x = ui.botaoVoltarConfiguracoes.x
    ui.botoesPausa.voltar.y = (alturaTela / 2) - 25
    ui.botoesPausa.menu.y = (alturaTela / 2) + 35
    ui.botoesPausa.configuracoes.y = (alturaTela / 2) + 95
    ui.botoesPausa.fechar.y = (alturaTela / 2) + 155

    local larguraBotaoResolucao = ui.botoesResolucao[1].largura
    local espacamentoResolucao = 12
    local larguraTotalResolucao =
        #ui.botoesResolucao * larguraBotaoResolucao
        + (#ui.botoesResolucao - 1) * espacamentoResolucao
    local xResolucao = (larguraTela - larguraTotalResolucao) / 2

    for indice, botao in ipairs(ui.botoesResolucao) do
        botao.x = xResolucao + (indice - 1) *
            (larguraBotaoResolucao + espacamentoResolucao)
        botao.y = alturaTela * 0.62
    end

    local tituloLargura = ui.fonteTitulo:getWidth(ui.titulo)
    ui.tituloX = math.min(
        ui.tituloX,
        math.max(0, larguraTela - tituloLargura)
    )
end

function UI.update(ui, dt, larguraTela, estado)
    if estado ~= "menu" then
        return
    end

    local tituloLargura = ui.fonteTitulo:getWidth(ui.titulo)
    local limiteDireito = math.max(0, larguraTela - tituloLargura)

    ui.tituloX = ui.tituloX
        + ui.velocidadeTitulo * ui.tituloDirecao * dt
    ui.tempoJogadorMenu = ui.tempoJogadorMenu + dt

    if ui.tituloX >= limiteDireito then
        ui.tituloX = limiteDireito
        ui.tituloDirecao = -1
    elseif ui.tituloX <= 0 then
        ui.tituloX = 0
        ui.tituloDirecao = 1
    end
end

function UI.drawBackground(assets, larguraTela, alturaTela, cenarioAtual, transicao)
    local imagens = {
        fundo = assets.images.fundo,
        cena2 = assets.images.cena2,
        cenaEspecial = assets.images.cenaEspecial
    }
    local function desenharCena(nome, alpha)
        local imagem = imagens[nome] or imagens.fundo
        love.graphics.setColor(1,1,1,alpha)
        love.graphics.draw(imagem,0,0,0,
            larguraTela/imagem:getWidth(),alturaTela/imagem:getHeight())
    end
    if transicao then
        local progresso=math.min(1,transicao.tempo/transicao.duracao)
        local alpha=progresso*progresso*(3-2*progresso)
        desenharCena(transicao.origem,1)
        desenharCena(transicao.destino,alpha)
    else
        desenharCena(cenarioAtual,1)
    end
    love.graphics.setColor(1,1,1,1)
end

function UI.drawMenu(ui, assets, larguraTela, alturaTela)
    love.graphics.setColor(0, 0, 0, 0.45)
    love.graphics.rectangle("fill", 0, 0, larguraTela, alturaTela)

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(ui.fonteTitulo)
    love.graphics.printf(
        ui.titulo,
        ui.tituloX,
        55,
        ui.fonteTitulo:getWidth(ui.titulo),
        "center"
    )
    love.graphics.setFont(ui.fontePadrao)

    local imagemJogador = assets.images.jogador
    local escalaJogador = 64 / imagemJogador:getWidth()
    local centroX = imagemJogador:getWidth() / 2
    local centroY = imagemJogador:getHeight() / 2
    local movimentoJogador = math.sin(ui.tempoJogadorMenu * 2.5)
    local direcaoJogador = math.cos(ui.tempoJogadorMenu * 2.5) >= 0
        and 1
        or -1

    love.graphics.draw(
        imagemJogador,
        (larguraTela / 2) + movimentoJogador * 75,
        (alturaTela / 2) - 90 - movimentoJogador * movimentoJogador * 36,
        0,
        escalaJogador * 1.2 * direcaoJogador,
        escalaJogador * 1.2,
        centroX,
        centroY
    )

    desenharBotaoMenu(ui.botao, "Iniciar Jogo")
    desenharBotaoMenu(ui.botaoInstrucoes, "Instruções")
    desenharBotaoMenu(ui.botaoConfiguracoesMenu)
    desenharBotaoMenu(ui.botaoSair)
end

function UI.drawInstructions(ui, larguraTela, alturaTela)
    love.graphics.setColor(0, 0, 0, 0.82)
    love.graphics.rectangle("fill", 0, 0, larguraTela, alturaTela)

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf(
        "INSTRUÇÕES",
        0,
        100,
        larguraTela,
        "center"
    )

    local texto = [[
Movimentação: WASD ou teclas de seta
Mire com o mouse e segure o botão esquerdo para atirar.

Derrote os inimigos e os chefes para ganhar pontos.
Colete corações para recuperar vidas.
Os power-ups de tiro rápido e escudo ajudam durante a partida.

Pressione ESC para pausar ou voltar ao jogo.
Na tela de pausa, você pode voltar ao jogo ou ao menu principal.
Pressione R para jogar novamente após o fim da partida.

Depois de derrotar o segundo chefe, fique atento: um portal pode surgir
por alguns segundos. Entre nele para enfrentar o chefe secreto.
]]

    love.graphics.printf(
        texto,
        70,
        160,
        larguraTela - 140,
        "center"
    )

    local botao = ui.botaoVoltarInstrucoes
    local mouseX, mouseY = love.mouse.getPosition()

    if pontoDentroDoRetangulo(
        mouseX,
        mouseY,
        botao.x,
        botao.y,
        botao.largura,
        botao.altura
    ) then
        love.graphics.setColor(0.2, 0.6, 1)
    else
        love.graphics.setColor(0.1, 0.4, 0.8)
    end

    love.graphics.rectangle(
        "fill",
        botao.x,
        botao.y,
        botao.largura,
        botao.altura,
        8,
        8
    )

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf(
        botao.texto,
        botao.x,
        botao.y + 17,
        botao.largura,
        "center"
    )
end

function UI.isInstructionsButtonClicked(ui, mouseX, mouseY)
    local botao = ui.botaoInstrucoes

    return pontoDentroDoRetangulo(
        mouseX,
        mouseY,
        botao.x,
        botao.y,
        botao.largura,
        botao.altura
    )
end

function UI.isInstructionsBackClicked(ui, mouseX, mouseY)
    local botao = ui.botaoVoltarInstrucoes

    return pontoDentroDoRetangulo(
        mouseX,
        mouseY,
        botao.x,
        botao.y,
        botao.largura,
        botao.altura
    )
end

function UI.isStartButtonClicked(ui, mouseX, mouseY)
    local botao = ui.botao

    return pontoDentroDoRetangulo(
        mouseX,
        mouseY,
        botao.x,
        botao.y,
        botao.largura,
        botao.altura
    )
end

function UI.isExitButtonClicked(ui, mouseX, mouseY)
    local botao = ui.botaoSair

    return pontoDentroDoRetangulo(
        mouseX,
        mouseY,
        botao.x,
        botao.y,
        botao.largura,
        botao.altura
    )
end

function UI.isMenuSettingsButtonClicked(ui, mouseX, mouseY)
    local botao = ui.botaoConfiguracoesMenu

    return pontoDentroDoRetangulo(
        mouseX,
        mouseY,
        botao.x,
        botao.y,
        botao.largura,
        botao.altura
    )
end

function UI.drawHUD(dados, assets, larguraTela, alturaTela)
    local player = dados.player
    local bosses = dados.bosses
    local boss = bosses.boss

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("Pontos: " .. dados.pontos, 20, 20)

    local yPowerup = 44

    if dados.timerTiroRapido > 0 then
        local imagem = assets.images.powerupTiroRapido
        local escala = 18 / imagem:getWidth()

        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(imagem, 20, yPowerup, 0, escala, escala)

        love.graphics.setColor(0.9, 0.45, 1, 1)
        love.graphics.print(
            string.format("Tiro 2x: %.1fs", dados.timerTiroRapido),
            44,
            yPowerup + 1
        )

        yPowerup = yPowerup + 22
    end

    if dados.timerEscudo > 0 then
        local imagem = assets.images.powerupEscudo
        local escala = 18 / imagem:getWidth()

        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(imagem, 20, yPowerup, 0, escala, escala)

        love.graphics.setColor(0.3, 0.85, 1, 1)
        love.graphics.print(
            string.format("Escudo: %.1fs", dados.timerEscudo),
            44,
            yPowerup + 1
        )
    end

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf(
        "Tempo: " .. formatarTempo(dados.tempoPartida),
        0,
        20,
        larguraTela,
        "center"
    )

    love.graphics.print(
        "Vidas: " .. player.vidas,
        larguraTela - 100,
        20
    )

    -- Barra de vida do chefe
    if boss then
        local barraLargura = 90
        local barraAltura = 8
        local barraX = boss.x - barraLargura / 2
        local barraY = boss.y - boss.tamanho / 2 - 16
        local proporcaoVida = math.max(0, boss.vida / boss.vidaMaxima)

        love.graphics.setColor(0.1, 0.1, 0.1, 0.8)
        love.graphics.rectangle(
            "fill",
            barraX,
            barraY,
            barraLargura,
            barraAltura,
            3,
            3
        )

        love.graphics.setColor(0.9, 0.2, 0.2, 1)
        love.graphics.rectangle(
            "fill",
            barraX,
            barraY,
            barraLargura * proporcaoVida,
            barraAltura,
            3,
            3
        )

        love.graphics.setColor(1, 1, 1, 0.8)
        love.graphics.rectangle(
            "line",
            barraX,
            barraY,
            barraLargura,
            barraAltura,
            3,
            3
        )
    end

    -- Aviso de chegada ou batalha do chefe
    if bosses.bossEntrando and boss then
        love.graphics.setColor(0, 0, 0, 0.6)
        love.graphics.rectangle(
            "fill",
            0,
            alturaTela / 2 - 45,
            larguraTela,
            80
        )

        love.graphics.setColor(1, 0.2, 0.2, 1)
        love.graphics.printf(
            boss.tipo == 3
            and "! O CHEFE SECRETO ESTÁ CHEGANDO !"
            or "! ATENÇÃO: O CHEFÃO ESTÁ CHEGANDO !",
            0,
            alturaTela / 2 - 30,
            larguraTela,
            "center"
        )

        love.graphics.setColor(1, 1, 0, 1)
        love.graphics.printf(
            "BATALHA EM: " .. math.ceil(bosses.timerIntro) .. "s",
            0,
            alturaTela / 2 + 5,
            larguraTela,
            "center"
        )
    elseif boss then
        love.graphics.setColor(1, 0.3, 0.3, 1)
        love.graphics.printf(
            "! " .. boss.nome .. " EM BATALHA !",
            0,
            42,
            larguraTela,
            "center"
        )
    end

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf(
        "WASD/Setas: mover | Segure Clique Esquerdo: atirar | ESC: pausar",
        0,
        alturaTela - 30,
        larguraTela,
        "center"
    )
end

function UI.drawGameOver(pontos, tempoPartida, larguraTela, alturaTela)
    love.graphics.setColor(0, 0, 0, 0.75)
    love.graphics.rectangle("fill", 0, 0, larguraTela, alturaTela)

    love.graphics.setColor(1, 0.3, 0.3, 1)
    love.graphics.printf(
        "FIM DE JOGO!",
        0,
        alturaTela / 2 - 70,
        larguraTela,
        "center"
    )

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf(
        "Pontuação Final: " .. pontos,
        0,
        alturaTela / 2 - 30,
        larguraTela,
        "center"
    )

    love.graphics.printf(
        "Tempo Sobrevivido: " .. formatarTempo(tempoPartida),
        0,
        alturaTela / 2 - 5,
        larguraTela,
        "center"
    )

    love.graphics.printf(
        "Pressione R para jogar novamente ou ESC para o menu",
        0,
        alturaTela / 2 + 30,
        larguraTela,
        "center"
    )
end

local function desenharBotao(uiBotao)
    local mouseX, mouseY = love.mouse.getPosition()

    local mouseSobre =
        mouseX >= uiBotao.x
        and mouseX <= uiBotao.x + uiBotao.largura
        and mouseY >= uiBotao.y
        and mouseY <= uiBotao.y + uiBotao.altura

    if mouseSobre then
        love.graphics.setColor(0.2, 0.6, 1, 1)
    else
        love.graphics.setColor(0.1, 0.4, 0.8, 1)
    end

    love.graphics.rectangle(
        "fill",
        uiBotao.x,
        uiBotao.y,
        uiBotao.largura,
        uiBotao.altura,
        8,
        8
    )

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf(
        uiBotao.texto,
        uiBotao.x,
        uiBotao.y + 17,
        uiBotao.largura,
        "center"
    )
end

function UI.drawPauseMenu(ui, larguraTela, alturaTela)
    love.graphics.setColor(0, 0, 0, 0.72)
    love.graphics.rectangle("fill", 0, 0, larguraTela, alturaTela)

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf(
        "JOGO PAUSADO",
        0,
        alturaTela / 2 - 150,
        larguraTela,
        "center"
    )

    desenharBotao(ui.botoesPausa.voltar)
    desenharBotao(ui.botoesPausa.menu)
    desenharBotao(ui.botoesPausa.configuracoes)
    desenharBotao(ui.botoesPausa.fechar)

    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.printf(
        "Pressione ESC para voltar ao jogo",
        0,
        alturaTela - 30,
        larguraTela,
        "center"
    )

    love.graphics.setColor(1, 1, 1, 1)
end

function UI.drawSettingsMenu(
    ui,
    larguraTela,
    alturaTela,
    volume,
    resolucaoAtual
)
    love.graphics.setColor(0, 0, 0, 0.82)
    love.graphics.rectangle("fill", 0, 0, larguraTela, alturaTela)

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf(
        "CONFIGURAÇÕES",
        0,
        alturaTela * 0.16,
        larguraTela,
        "center"
    )

    local volumePercentual = math.floor(volume * 100 + 0.5)
    love.graphics.printf(
        "Volume: " .. volumePercentual .. "%",
        0,
        ui.configuracaoVolume.y - 42,
        larguraTela,
        "center"
    )

    local slider = ui.configuracaoVolume
    local indicadorX = slider.x + slider.largura * volume

    love.graphics.setColor(0.18, 0.18, 0.18, 1)
    love.graphics.rectangle(
        "fill",
        slider.x,
        slider.y,
        slider.largura,
        slider.altura,
        7,
        7
    )
    love.graphics.setColor(0.2, 0.7, 0.95, 1)
    love.graphics.rectangle(
        "fill",
        slider.x,
        slider.y,
        slider.largura * volume,
        slider.altura,
        7,
        7
    )
    love.graphics.circle(
        "fill",
        indicadorX,
        slider.y + slider.altura / 2,
        11
    )

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf(
        "Tamanho da tela",
        0,
        alturaTela * 0.5,
        larguraTela,
        "center"
    )

    for indice, botao in ipairs(ui.botoesResolucao) do
        desenharBotaoMenu(botao, botao.texto, indice == resolucaoAtual)
    end

    love.graphics.setColor(1, 1, 1, 0.75)
    love.graphics.printf(
        "Clique na barra para ajustar o volume e escolha uma resolução.",
        20,
        alturaTela * 0.75,
        larguraTela - 40,
        "center"
    )

    desenharBotao(ui.botaoVoltarConfiguracoes)

    love.graphics.setColor(1, 1, 1, 1)
end

function UI.pauseAction(ui, mouseX, mouseY)
    for _, botao in pairs(ui.botoesPausa) do
        if pontoDentroDoRetangulo(
            mouseX,
            mouseY,
            botao.x,
            botao.y,
            botao.largura,
            botao.altura
        ) then
            return botao.acao
        end
    end

    return nil
end

function UI.settingsAction(ui, mouseX, mouseY)
    local botao = ui.botaoVoltarConfiguracoes

    if pontoDentroDoRetangulo(
        mouseX,
        mouseY,
        botao.x,
        botao.y,
        botao.largura,
        botao.altura
    ) then
        return "voltar"
    end

    local slider = ui.configuracaoVolume
    if mouseY >= slider.y - 16
    and mouseY <= slider.y + slider.altura + 16
    and mouseX >= slider.x - 12
    and mouseX <= slider.x + slider.largura + 12 then
        ui.ajustandoVolume = true
        return "volume", UI.volumeAt(ui, mouseX)
    end

    for indice, resolucao in ipairs(ui.botoesResolucao) do
        if pontoDentroDoRetangulo(
            mouseX,
            mouseY,
            resolucao.x,
            resolucao.y,
            resolucao.largura,
            resolucao.altura
        ) then
            return "resolucao", indice
        end
    end

    return nil
end

function UI.volumeAt(ui, mouseX)
    local slider = ui.configuracaoVolume
    return math.max(
        0,
        math.min(1, (mouseX - slider.x) / slider.largura)
    )
end

return UI