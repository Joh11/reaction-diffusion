using SimpleDirectMediaLayer
const SDL2 = SimpleDirectMediaLayer
using ColorTypes

@kwdef struct Parameters
    dt :: Float64
    dx :: Float64
    D :: Float64
end

function scalingparameter(params::Parameters)
    params.D * params.dt / params.dx^2
end

abstract type Reaction end

@kwdef struct GrayScott <: Reaction
    k :: Float64 = 0.06264
    f :: Float64 = 0.06100
end

function initρ(w, h)
    # only a single channel for now
    ρ = zeros(w, h, 3)
    r = 5
    ρ[w÷2-r:w÷2+r, h÷2-r:h÷2+r, 1] .= 0.7
    r = 10
    ρ[w÷2-r:w÷2+r, h÷2-r:h÷2+r, 2] .= 0.3
    ρ
end

function diffusionpart(params::Parameters, ρ)
    dρ = -4ρ + circshift(ρ, [1, 0]) + circshift(ρ, [-1, 0]) + circshift(ρ, [0, 1]) + circshift(ρ, [0, -1])

    scalingparameter(params) * dρ
end

function update(params::Parameters, ρ, nothing::Nothing)
    ρ + diffusionpart(params, ρ)
end

function update(params::Parameters, ρ, gs::GrayScott)
    u = ρ[:, :, 1]
    v = ρ[:, :, 2]

    du = (-u .* v.^2 + gs.f * (1 .- u)) * params.dt
    dv = (u .* v.^2 - (gs.f + gs.k) * v) * params.dt

    ρ + diffusionpart(params, ρ) + stack((du, dv, zeros(size(du))))
end

function datafromρ(ρ)
    ARGB32.(clamp.(ρ[:, :, 1], 0, 1), clamp.(ρ[:, :, 2], 0, 1), clamp.(ρ[:, :, 3], 0, 1), 1)
end

@assert SDL2.init() == 0

# logical size
w = Int32(100)
h = Int32(100)

params = Parameters(dt=1, dx=1, D=0.2)
println("Parameters:")
@show params
@show scalingparameter(params)

reaction = GrayScott()

try
    @show win = SDL2.CreateWindow("Reaction diffusion", Int32(SDL2.WINDOWPOS_CENTERED()), Int32(SDL2.WINDOWPOS_CENTERED()), w, h, SDL2.WINDOW_RESIZABLE)
    SDL2.SetWindowSize(win, Int32(800), Int32(800))

    @show render = SDL2.CreateRenderer(win, Int32(-1), UInt32(0))

    SDL2.RenderSetLogicalSize(render, w, h)
    
    SDL2.SetRenderDrawColor(render, 0, 0, 0, 255)
    SDL2.RenderClear(render)
    SDL2.RenderPresent(render)

    texture = SDL2.CreateTexture(render, SDL2.PIXELFORMAT_ARGB8888,
                                 Int32(SDL2.TEXTUREACCESS_STREAMING), w, h)

    ρ = initρ(w, h)
    data = fill(ARGB32(0, 0, 0, 0), w, h)
    
    data .= datafromρ(ρ)

    @show SDL2.UpdateTexture(texture, C_NULL, pointer(data), Int32(w * sizeof(UInt32)))
    SDL2.RenderCopy(render, texture, C_NULL, C_NULL)
    SDL2.RenderPresent(render)

    quit = false
    tick = 0
    while !quit
        event = SDL2.event()
        while !isnothing(event)
            if event isa SDL2.QuitEvent
                @show event
                quit = true
            end
            event = SDL2.event()
        end

        ρ = update(params, ρ, reaction)
        data .= datafromρ(ρ)

        SDL2.RenderClear(render)
        
        SDL2.UpdateTexture(texture, C_NULL, pointer(data), Int32(w * sizeof(UInt32)))
        SDL2.RenderCopy(render, texture, C_NULL, C_NULL)
        
        SDL2.RenderPresent(render)
        
        SDL2.Delay(UInt32(30))

        if tick % 10 == 0
            println(sum(ρ))
        end
        tick += 1
    end

finally
    SDL2.Quit()
end
