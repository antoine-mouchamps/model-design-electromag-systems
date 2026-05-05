import matplotlib.pyplot as plt

plt.rcParams.update({"text.usetex": True, "font.family": "cm"})
plt.rcParams.update({"font.size": 20})

RESIDUALS = [
    0.00143637194246,
    4.7778728012e-05,
    1.5892867513e-06,
    5.28661789593e-08,
    1.78750865951e-09,
    3.26120222521e-10,
]

if __name__ == "__main__":
    fig, ax = plt.subplots(figsize=(9, 5))
    ax.semilogy(RESIDUALS, marker="o")
    ax.set_xlabel("Iteration")
    ax.set_ylabel("Residual")
    ax.grid(True, alpha=0.5, linestyle="--", color="gray")

    fig.tight_layout()
    fig.savefig("residuals.pdf", bbox_inches="tight")
