export type IbdType = "crohns" | "uc";

export interface PatientBasicInfo {
  name: string;
  sex: "male" | "female" | "other";
  birthDate: string;
  diagnosisDate: string;
  ibdType: IbdType;
}
