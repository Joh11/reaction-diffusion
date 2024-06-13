using SimpleDirectMediaLayer
const SDL2 = SimpleDirectMediaLayer
using ColorTypes
using DelimitedFiles

abstract type Parameters end

function scalingparameter(p::Parameters)
    dt(p) / dx(p)^2 * D(p)
end

@kwdef struct GrayScott <: Parameters
    dt :: Float64
    dx :: Float64
    
    k :: Float64 = 0.062
    f :: Float64 = 0.055
    Du :: Float64 = 1
    Dv :: Float64 = 0.5
end

function dt(gs::GrayScott) gs.dt end
function dx(gs::GrayScott) gs.dx end
function D(gs::GrayScott) return [gs.Du, gs.Dv] end

# function initρ(w, h)
#     ρ = zeros(w, h, 2)
#     r = 5
#     ρ[w÷2-r:w÷2+r, h÷2-r:h÷2+r, 1] .= 0.7
#     r = 10
#     ρ[w÷2-r:w÷2+r, h÷2-r:h÷2+r, 2] .= 0.3
#     ρ
# end

# function initρ(w, h)
#     ρ = zeros(w, h, 2)
#     ρ[:, :, 1] .= 1
#     r = 5
#     ρ[w÷2-r:w÷2+r, h÷2-r:h÷2+r, 2] .= 1
#     ρ
# end

function initρ(w, h)
    @assert w == h
    
    x = repeat(0:w-1, 1, h) .- w/2
    y = repeat(0:h-1, 1, w)' .- h/2
    r = .√(x.^2 + y.^2)
    
    ρ = zeros(w, h, 2)
    ρ[:, :, 1] .= 1

    r0 = .4 * (w + h) / 2
    
    @views reshape(ρ[:, :, 2], :)[reshape(r, :) .< r0] .= 1
    
    ρ
end

# function initρ(w, h)
#     ρ = zeros(w, h, 2)
#     ρ[1:end, 1:end, 1:2] = rand(w, h, 2)
#     ρ
# end

function diffusion(p, ρ)
    dρ = -4ρ +
        0.8 * (circshift(ρ, [1, 0]) + circshift(ρ, [-1, 0]) +
        circshift(ρ, [0, 1]) + circshift(ρ, [0, -1])) +
        0.2 * (circshift(ρ, [1, 1]) + circshift(ρ, [-1, 1]) +
        circshift(ρ, [1, -1]) + circshift(ρ, [-1, -1]))
    
    reshape(scalingparameter(p), 1, 1, :) .* dρ
end

# function update(p::GrayScott, ρ)
#     u = ρ[:, :, 1]
#     v = ρ[:, :, 2]

#     du = (-u .* v.^2 + p.f * (1 .- u)) * dt(p)
#     dv = (u .* v.^2 - (p.f + p.k) * v) * dt(p)

#     ρ2 = ρ + diffusion(p, ρ) + stack((du, dv))
#     ρ2
# end

# the one with extent
# function update(p::GrayScott, ρ)
#     u = ρ[:, :, 1]
#     v = ρ[:, :, 2]

#     x = u .* v.^2 .* (1 .- v).^3
#     du = (-x + p.f * (1 .- u)) * dt(p)
#     dv = (x - (p.f + p.k) * v) * dt(p)

#     ρ2 = ρ + diffusion(p, ρ) + stack((du, dv))
#     ρ2
# end

# with disorder
function update(p::GrayScott, ρ)
    # α = 2e-5
    α = 1e-5 # disorder
    u = ρ[:, :, 1]
    v = ρ[:, :, 2]

    du = (-u .* v.^2 + p.f * (1 .- u)) * dt(p)
    dv = (u .* v.^2 - (p.f + p.k) * v) * dt(p)

    ρ + diffusion(p, ρ) + stack((du, dv)) + √(α * dt(p)) * randn(size(ρ))
end

function datafromρ(ρ)
    nchannels = size(ρ, 3)
    
    if nchannels == 1
        ARGB32.(clamp.(ρ[:, :, 1], 0, 1), 0, 0, 1)
    elseif nchannels == 2
        ARGB32.(clamp.(ρ[:, :, 1], 0, 1), clamp.(ρ[:, :, 2], 0, 1), 0, 1)
    elseif nchannels >= 3
        ARGB32.(clamp.(ρ[:, :, 1], 0, 1), clamp.(ρ[:, :, 2], 0, 1),
                clamp.(ρ[:, :, 3], 0, 1), 1)
    end
end

@assert SDL2.init() == 0

# logical size
w = Int32(400)
h = Int32(400)

# this one is found to work
# p = GrayScott(dt=1, dx=5, Du=5, Dv=5/2)

p = GrayScott(dt=1, dx=5, Du=5, Dv=5/2)

println("Parameters:")
@show p
@show scalingparameter(p)

stepspertick = 30

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
            elseif event isa SDL2.KeyboardEvent && event.repeat == 0
                if event.keysym.sym == SDL2.GetKeyFromName("r")
                    println("reset")
                    ρ = initρ(w, h)
                elseif event.keysym.sym == SDL2.GetKeyFromName("s")
                    println("save")
                    writedlm("rho.dat", ρ)
                elseif event.keysym.sym == SDL2.GetKeyFromName("l")
                    println("load")
                    ρ = reshape(readdlm("rho.dat"), Int(w), Int(h), :)
                end
            end
            event = SDL2.event()
        end

        for n in 1:stepspertick
            ρ = update(p, ρ)
        end

        data .= datafromρ(ρ)

        SDL2.RenderClear(render)
        
        SDL2.UpdateTexture(texture, C_NULL, pointer(data), Int32(w * sizeof(UInt32)))
        SDL2.RenderCopy(render, texture, C_NULL, C_NULL)
        
        SDL2.RenderPresent(render)
        
        # SDL2.Delay(UInt32(30))

        if tick % 1 == 0
            println(sum(ρ))
        end
        tick += 1
    end

finally
    SDL2.Quit()
end
