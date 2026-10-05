import React from "react";
import { render, screen, waitFor } from "@testing-library/react";
import Page from "../app/page";

describe("Frontend Page Component", () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it("renders loading state initially", () => {
    global.fetch = jest.fn(() => new Promise(() => {})); // pending promise

    render(<Page />);
    expect(screen.getByText("Loading...")).toBeInTheDocument();
  });

  it("renders list of attractions on successful fetch", async () => {
    const mockData = [
      {
        id: 1,
        name: "Phi Phi Islands",
        detail: "Beautiful island in Thailand",
        coverimage: "https://example.com/phiphi.jpg",
        latitude: "7.7376190",
        longitude: "98.7068755",
      },
      {
        id: 2,
        name: "Eiffel Tower",
        detail: "Iconic tower in Paris",
        coverimage: "https://example.com/eiffel.jpg",
        latitude: "48.8583736",
        longitude: "2.2922926",
      },
    ];

    global.fetch = jest.fn().mockResolvedValue({
      ok: true,
      json: async () => mockData,
    });

    render(<Page />);

    await waitFor(() => {
      expect(screen.getByText("Phi Phi Islands")).toBeInTheDocument();
      expect(screen.getByText("Eiffel Tower")).toBeInTheDocument();
    });

    expect(screen.getByText("Beautiful island in Thailand")).toBeInTheDocument();
    expect(screen.getByText("Iconic tower in Paris")).toBeInTheDocument();
  });

  it("renders error state when fetch fails", async () => {
    global.fetch = jest.fn().mockRejectedValue(new Error("Network Error"));

    render(<Page />);

    await waitFor(() => {
      expect(screen.getByText("Error: Network Error")).toBeInTheDocument();
    });
  });

  it("renders empty state when no attractions returned", async () => {
    global.fetch = jest.fn().mockResolvedValue({
      ok: true,
      json: async () => [],
    });

    render(<Page />);

    await waitFor(() => {
      expect(screen.getByText("No attractions found.")).toBeInTheDocument();
    });
  });
});

