package com.emsi.telemedicine.dto;

import com.emsi.telemedicine.entity.Patient;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Past;
import jakarta.validation.constraints.Size;

import java.time.LocalDate;

/**
 * Objet échangé avec l'API REST (JSON). L'id est ignoré en entrée.
 */
public record PatientDTO(
        Long id,
        @NotBlank(message = "le nom est obligatoire") @Size(max = 100) String nom,
        @NotBlank(message = "le prénom est obligatoire") @Size(max = 100) String prenom,
        @NotBlank(message = "l'email est obligatoire") @Email(message = "email invalide") @Size(max = 150) String email,
        @NotNull(message = "la date de naissance est obligatoire") @Past(message = "la date de naissance doit être dans le passé") LocalDate dateNaissance
) {

    public static PatientDTO fromEntity(Patient p) {
        return new PatientDTO(p.getId(), p.getNom(), p.getPrenom(), p.getEmail(), p.getDateNaissance());
    }

    /** Copie les champs modifiables du DTO vers l'entité. */
    public void applyTo(Patient p) {
        p.setNom(nom);
        p.setPrenom(prenom);
        p.setEmail(email);
        p.setDateNaissance(dateNaissance);
    }
}
