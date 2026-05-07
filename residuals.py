import matplotlib.pyplot as plt

plt.rcParams.update({"text.usetex": True, "font.family": "cm"})
plt.rcParams.update({"font.size": 20})

RESIDUALS = [
    0.00136756156615,
    4.54891403415e-05,
    1.51310334223e-06,
    5.03321866022e-08,
    1.73027327371e-09,
    4.40705567393e-10,
]

if __name__ == "__main__":
    fig, ax = plt.subplots(figsize=(9, 5))
    ax.semilogy(RESIDUALS, marker="o")
    ax.set_xlabel("Iteration")
    ax.set_ylabel("Residual")
    ax.grid(True, alpha=0.5, linestyle="--", color="gray")

    fig.tight_layout()
    fig.savefig("residuals.pdf", bbox_inches="tight")
